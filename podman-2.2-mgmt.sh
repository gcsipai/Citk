#!/bin/bash
#
# Cél: Podman konténerek interaktív listázása és konzol megnyitása (menüsen, számmal történő választással).
# Verzió: 2.2 citk 2025
#

# --- Színek és Konfiguráció ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Globális változók
CURRENT_USER=""
IS_ROOT=false
declare -gA container_map # Globális asszociatív tömb a konténerek tárolására

# --- Segédfunkciók ---

# Parancs futtatása a normál felhasználóként
run_as_user() {
    local user=$1
    shift
    local command=("$@")
    
    if ! id -u "$user" &>/dev/null; then
        echo -e "${RED}❌ Hiba: A felhasználó ($user) nem létezik.${NC}" >&2
        return 1
    fi
    
    # Egyszerűbb megoldás: sudo használata a felhasználó váltáshoz
    sudo -u "$user" bash -c "${command[*]}"
}

# Felhasználó beállítása és érvényesítése
setup_user() {
    if [[ $EUID -eq 0 ]]; then
        IS_ROOT=true
        while true; do
            read -r -p "Kérjük, adja meg a normál (rootless) felhasználónevet: " input_user
            if id -u "$input_user" &>/dev/null; then
                CURRENT_USER="$input_user"
                break
            else
                echo -e "${RED}❌ Hiba: A felhasználó ($input_user) nem létezik. Próbálja újra.${NC}"
            fi
        done
    else
        CURRENT_USER="$USER"
    fi
    echo -e "${BLUE}ℹ️  Műveleti felhasználó: ${BOLD}$CURRENT_USER${NC}"
}

# Konténerek gyűjtése és listázása interaktív választáshoz
list_and_select_containers() {
    clear
    echo -e "${BOLD}${MAGENTA}--- KONTÉNER KONZOL BELÉPÉS ---${NC}"
    echo -e "${YELLOW}ℹ️  Aktív konténerek keresése a(z) ${BOLD}root${NC}${YELLOW} és ${BOLD}${CURRENT_USER}${NC}${YELLOW} felhasználóknál...${NC}"

    local container_list=()
    container_map=() # Töröljük a korábbi tartalmat
    
    # Root konténerek (csak aktívak)
    if [[ "$IS_ROOT" == "true" ]]; then
        mapfile -t root_containers < <(podman ps --format "{{.ID}}~{{.Names}}~root" 2>/dev/null || true)
        container_list+=("${root_containers[@]}")
    fi
    
    # Rootless konténerek (csak aktívak)
    mapfile -t user_containers < <(run_as_user "$CURRENT_USER" "podman ps --format \"{{.ID}}~{{.Names}}~rootless\"" 2>/dev/null || true)
    container_list+=("${user_containers[@]}")

    local container_count=${#container_list[@]}
    
    if [[ $container_count -eq 0 ]]; then
        echo -e "${RED}❌ Nem található aktív Podman konténer. Nyomjon Entert a visszatéréshez.${NC}"
        read -r
        return 2
    fi
    
    # Listázás
    echo -e "\n${BOLD}${GREEN}Válasszon egy konténert a sorszám megadásával: ${NC}"
    local i=1
    
    echo -e " ${BOLD}# ID           NÉV                      TÍPUS${NC}"
    echo "-----------------------------------------------------"
    for entry in "${container_list[@]}"; do
        IFS='~' read -r id name source_user <<< "$entry"
        container_map[$i]="$id~$name~$source_user"
        
        local short_name="${name:0:22}"
        local short_id="${id:0:12}"
        local display_user=""
        
        if [[ "$source_user" == "root" ]]; then
            display_user="root"
        else
            display_user="rootless ($CURRENT_USER)"
        fi
        
        printf " ${BOLD}%2d)${NC} %-12s %-22s %s\n" "$i" "$short_id" "$short_name" "$display_user"
        i=$((i + 1))
    done
    echo "-----------------------------------------------------"

    # Kiválasztás
    local choice=""
    while true; do
        read -r -p "Választás [1-$((container_count))] vagy (M)enü: " choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$container_count" ]]; then
            return "$choice"
        elif [[ "$choice" =~ ^[Mm]$ ]]; then
            return 255
        else
            echo -e "${RED}Érvénytelen választás. Kérem a sorszámot vagy M-et adjon meg.${NC}"
        fi
    done
}

# Belépés a konténer konzolba
exec_into_container() {
    local choice=$1
    
    IFS='~' read -r target_id target_name target_user <<< "${container_map[$choice]}"
    
    echo -e "\n${BOLD}${GREEN}Belépés a(z) ${target_name} (${target_id:0:12}) konténerbe (felhasználó: $target_user)...${NC}"
    echo "Kilépéshez írja be: ${BOLD}exit${NC}"
    echo -e "${MAGENTA}------------------ KONZOL INDÍTÁSA ------------------${NC}"

    local exec_command="podman exec -it \"$target_id\""
    local shell_found=false
    
    # Shell keresése a konténerben
    if [[ "$target_user" == "root" ]]; then
        # Root konténerek
        if podman exec "$target_id" which bash &>/dev/null; then
            exec_command="$exec_command /bin/bash"
            shell_found=true
        elif podman exec "$target_id" which sh &>/dev/null; then
            exec_command="$exec_command /bin/sh"
            shell_found=true
        fi
    else
        # Rootless konténerek
        if run_as_user "$CURRENT_USER" "podman exec \"$target_id\" which bash" &>/dev/null; then
            exec_command="$exec_command /bin/bash"
            shell_found=true
        elif run_as_user "$CURRENT_USER" "podman exec \"$target_id\" which sh" &>/dev/null; then
            exec_command="$exec_command /bin/sh"
            shell_found=true
        fi
    fi
    
    if [[ "$shell_found" == "false" ]]; then
        echo -e "${RED}❌ Nem található megfelelő shell a konténerben.${NC}"
        read -r -p "Nyomjon Enter-t a folytatáshoz..."
        return 1
    fi
    
    # Parancs végrehajtása
    if [[ "$target_user" == "root" ]]; then
        eval "$exec_command"
    else
        run_as_user "$CURRENT_USER" "$exec_command"
    fi
    
    local exit_code=$?
    echo -e "${MAGENTA}------------------ KONZOL BEZÁRVA -------------------${NC}"
    
    if [[ $exit_code -ne 0 ]]; then
        echo -e "${YELLOW}⚠️  A konzol nem standard módon zárt. Kilépési kód: $exit_code${NC}"
    fi
    
    read -r -p "Nyomjon Enter-t a főmenühöz való visszatéréshez..."
}

# Fő menü
show_menu() {
    while true; do
        clear
        echo -e "${BOLD}${BLUE}╔══════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}${BLUE}║         PODMAN KONZOL MENEDZSER (v2.2)           ║${NC}"
        echo -e "${BOLD}${BLUE}╚══════════════════════════════════════════════════╝${NC}"
        echo -e "Műveleti felhasználó: ${BOLD}$CURRENT_USER${NC}"
        echo "-----------------------------------------------------"
        echo -e "${GREEN}1) 💻 Belépés aktív konténer konzoljába (EXEC)${NC}"
        echo -e "${YELLOW}2) ♻️  Frissítés és Belépési Lista Megjelenítése${NC}"
        echo -e "${RED}3) 🚪 Kilépés${NC}"
        echo "-----------------------------------------------------"
        
        read -r -p "Választás [1-3]: " menu_choice
        
        case "$menu_choice" in
            1|2)
                list_and_select_containers
                local selection=$?
                
                if [[ $selection -ge 1 ]] && [[ $selection -le 254 ]]; then
                    exec_into_container "$selection"
                fi
                ;;
            3)
                echo -e "${BLUE}Viszlát! 👋${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Érvénytelen választás. Kérem 1, 2, vagy 3-at adjon meg.${NC}"
                read -r -p "Nyomjon Enter-t a folytatáshoz..."
                ;;
        esac
    done
}

# Ellenőrzés: podman telepítve van-e?
check_dependencies() {
    if ! command -v podman &>/dev/null; then
        echo -e "${RED}❌ A Podman nincs telepítve vagy nem elérhető.${NC}"
        exit 1
    fi
}

# --- Fő program indulása ---
main() {
    check_dependencies
    setup_user
    show_menu
}

# Handler a CTRL+C megnyomásához
trap 'echo -e "\n${BLUE}Script megszakítva. Kilépés...${NC}"; exit 0' INT

# Program indítása
main "$@"

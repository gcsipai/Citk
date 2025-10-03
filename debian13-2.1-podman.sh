#!/bin/bash
#
# Podman management script for Debian 13 (Trixie)
# Cél: Megbízható telepítés, rootless beállítás, Cockpit és a Docker kompatibilitás kezelése.
# Verzió: 2.1 - Citk 2025
#

# --- Hibakezelés és Globális Beállítások ---
set -euo pipefail
IFS=$'\n\t'

# Hiba esetén kiírja, melyik sorban, melyik parancs hibázott
trap 'error_handler $? $LINENO' ERR

error_handler() {
    local exit_code=$1
    local line_no=$2
    local last_command=${BASH_COMMAND}
    
    echo -e "${RED}❌ Váratlan hiba történt a $line_no sorban a(z) \"$last_command\" parancs futtatása közben (kilépési kód: $exit_code)${NC}" >&2
    exit $exit_code
}

# Globális Változók
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.1"
IS_ROOT=false
CURRENT_USER=""
USER_HOME=""
BASHRC_FILE=""

# Színek a kimenethez
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'
readonly UNDERLINE='\033[4m'

# --- Vizuális Segédfunkciók ---

# Színes kimenet
print_status() {
    local type=$1
    local message=$2
    case $type in
        "success") echo -e "${GREEN}${BOLD}✅ ${message}${NC}" ;;
        "error") echo -e "${RED}❌ ${message}${NC}" >&2 ;;
        "warning") echo -e "${YELLOW}⚠️  ${message}${NC}" ;;
        "info") echo -e "${BLUE}ℹ️  ${message}${NC}" ;;
        "highlight") echo -e "${MAGENTA}${BOLD}# ${message}${NC}" ;;
        *) echo "📢 ${message}" ;;
    esac
}

# Fejléc rajzolása
draw_header() {
    clear
    local title="PODMAN KONTÉNER KEZELŐ ESZKÖZ"
    local version="Verzió: $SCRIPT_VERSION | Debian 13"
    local len_title=${#title}
    local len_version=${#version}
    
    echo -e "${CYAN}${BOLD}╔$(printf '═%.0s' $(seq 1 $((len_title + 6))))╗${NC}"
    echo -e "${CYAN}${BOLD}║   ${title}   ║${NC}"
    echo -e "${CYAN}${BOLD}╠$(printf '═%.0s' $(seq 1 $((len_title + 6))))╣${NC}"
    echo -e "${MAGENTA}║ $(printf '%*s' $(( (len_title + 6 + len_version) / 2 )) "$version") $(printf '%*s' $(( (len_title + 6 - len_version) / 2 )) "" ) ${MAGENTA}║${NC}"
    echo -e "${CYAN}${BOLD}╚$(printf '═%.0s' $(seq 1 $((len_title + 6))))╝${NC}"
    echo ""
}

# --- Rendszer / Logikai Segédfunkciók (változatlanul hagytam a konzisztencia és megbízhatóság miatt) ---

# Root jogosultság ellenőrzése
check_root_privileges() {
    if [[ $EUID -eq 0 ]]; then
        IS_ROOT=true
        print_status "info" "Root jogosultságok érvényesítve"
    else
        print_status "error" "A szkript futtatásához root jogosultság szükséges"
        print_status "info" "Kérjük, futtassa újra: sudo ./$SCRIPT_NAME"
        exit 1
    fi
}

# Felhasználói környezet beállítása
set_user_context() {
    if [[ -z "${SUDO_USER:-}" ]]; then
        # Rootként fut sudo nélkül -> megkérdezi a felhasználót
        while true; do
            read -r -p "Kérjük, adja meg a normál felhasználónevet a Podman beállításhoz: " INPUT_USER
            if id -u "$INPUT_USER" &>/dev/null; then
                CURRENT_USER="$INPUT_USER"
                break
            else
                print_status "error" "A '$INPUT_USER' felhasználó nem létezik. Kérjük, próbálja újra."
            fi
        done
    else
        # Rootként fut sudo-val
        CURRENT_USER="$SUDO_USER"
    fi

    USER_HOME=$(eval echo "~$CURRENT_USER")
    BASHRC_FILE="$USER_HOME/.bashrc"

    if [[ ! -d "$USER_HOME" ]]; then
        print_status "error" "A felhasználói könyvtár ($USER_HOME) nem található"
        exit 1
    fi
    
    print_status "info" "Beállítandó felhasználó: ${BOLD}$CURRENT_USER${NC}${BLUE} (Home: $USER_HOME)${NC}"
}

# Felhasználó létezésének ellenőrzése
validate_user() {
    local user=$1
    if ! id -u "$user" &>/dev/null; then
        print_status "error" "A felhasználó ($user) nem létezik"
        return 1
    fi
    return 0
}

# Parancs futtatása a normál felhasználóként
run_as_user() {
    local user=$1
    shift
    local command=("$@")
    
    if ! validate_user "$user"; then
        return 1
    fi
    
    # su - beállítja a környezetet, ami elengedhetetlen a rootless funkciókhoz
    su - "$user" -c "${command[*]}"
}

# Parancs futtatása systemd --user környezetben (DBus hiba fixálása)
run_as_user_systemd() {
    local user=$1
    shift
    local command=("$@")
    
    if ! validate_user "$user"; then
        return 1
    fi

    local user_id
    user_id=$(id -u "$user")
    local xdg_dir="/run/user/$user_id"
    
    # XDG_RUNTIME_DIR létrehozása, ha nem létezik (gyakran hiányzik nem-interaktív su esetén)
    if [[ ! -d "$xdg_dir" ]]; then
        mkdir -p "$xdg_dir"
        chown "$user:$user" "$xdg_dir"
    fi

    # Környezeti változók explicit átadása a systemctl --user számára
    su - "$user" -c "export XDG_RUNTIME_DIR='$xdg_dir' && export DBUS_SESSION_BUS_ADDRESS='unix:path=$xdg_dir/bus' && ${command[*]}"
}

# Rendszer információk gyűjtése
system_info() {
    print_status "info" "Rendszer információk:"
    echo "  OS: $(lsb_release -d | cut -f2-)"
    echo "  Kernel: $(uname -r)"
    echo "  Arch: $(uname -m)"
}

# Csomag telepítés előtti ellenőrzés
check_package_availability() {
    local packages=("$@")
    local missing_packages=()
    
    print_status "info" "Csomag elérhetőség ellenőrzése..."
    
    for package in "${packages[@]}"; do
        if ! apt-cache show "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -gt 0 ]]; then
        print_status "warning" "A következő csomagok nem érhetők el: ${missing_packages[*]}"
        read -r -p "Folytatja a telepítést? (y/N): " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            print_status "info" "Telepítés megszakítva"
            exit 0
        fi
    fi
}

# Podman verzió ellenőrzése
check_podman_version() {
    if command -v podman &>/dev/null; then
        local podman_version
        podman_version=$(podman version --format '{{.Client.Version}}' 2>/dev/null || podman version | head -n1 | awk '{print $NF}')
        print_status "success" "Podman verzió: ${BOLD}$podman_version${NC}"
    else
        print_status "error" "Podman nincs telepítve"
        return 1
    fi
}

# Registry konfiguráció beállítása
setup_registry_config() {
    local registry_conf_dir="/etc/containers"
    local registry_conf_file="$registry_conf_dir/registries.conf"
    
    print_status "info" "Registry konfiguráció beállítása..."
    
    if [[ ! -f "$registry_conf_file" ]]; then
        mkdir -p "$registry_conf_dir"
        cat > "$registry_conf_file" << 'EOF'
# Podman registry konfiguráció
# Alapértelmezett registry-k kereséshez

unqualified-search-registries = ["docker.io", "registry.fedoraproject.org", "quay.io"]

[[registry]]
location = "docker.io"

[[registry]]
location = "registry.fedoraproject.org"

[[registry]]
location = "quay.io"
EOF
        print_status "success" "Alap registry konfiguráció létrehozva: $registry_conf_file"
    else
        print_status "info" "Registry konfiguráció már létezik. Kihagyva."
    fi
}

# Rootless Podman beállítása
setup_rootless_podman() {
    local user=$1
    
    print_status "highlight" "Rootless Podman Szolgáltatás Beállítása"
    
    # Linger engedélyezése
    if loginctl enable-linger "$user"; then
        print_status "success" "Linger engedélyezve a(z) $user felhasználó számára (session megőrzés)"
    else
        print_status "error" "Linger engedélyezése sikertelen"
        return 1
    fi
    
    # SubID beállítás ellenőrzése
    if ! grep -q "^$user:" /etc/subuid 2>/dev/null; then
        print_status "warning" "SubID beállítás szükséges a teljesen rootless működéshez. Kérem futtassa manuálisan: usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $user"
    fi
    
    # Podman socket indítása
    print_status "info" "Podman socket engedélyezése és indítása..."
    if run_as_user_systemd "$user" "systemctl --user enable podman.socket --now"; then
        print_status "success" "Podman socket sikeresen engedélyezve és elindítva"
    else
        print_status "error" "Podman socket indítása sikertelen"
        return 1
    fi
    
    sleep 2
    if run_as_user_systemd "$user" "systemctl --user is-active podman.socket" &>/dev/null; then
        print_status "success" "Podman socket aktív"
    else
        print_status "error" "Podman socket inaktív. Ellenőrizze a hibaüzeneteket."
        return 1
    fi
}

# --- Fő Funkciók ---

# 1. Podman telepítése és alapvető beállításai
main_setup() {
    draw_header
    echo -e "${YELLOW}1. ${BOLD}PODMAN TELEPÍTÉS ÉS ROOTLESS BEÁLLÍTÁS${NC}"
    echo "---------------------------------------------------------"
    
    system_info
    set_user_context

    # Telepítési parancsok
    print_status "info" "Rendszer csomaglistájának frissítése..."
    apt update -qq

    local required_packages=("podman" "podman-compose" "uidmap" "fuse-overlayfs" "slirp4netns" "crun" "buildah" "netavark")
    check_package_availability "${required_packages[@]}"

    print_status "info" "Podman és kapcsolódó csomagok telepítése..."
    apt install -y "${required_packages[@]}"
    print_status "success" "Podman és a szükséges csomagok telepítve"
    
    check_podman_version
    setup_registry_config

    # Aliasok és környezeti változók beállítása
    print_status "highlight" "Aliasok és Docker Kompatibilitás Beállítása"
    local bashrc_addition=$(cat << 'EOF'
# --- Podman Beállítások (Docker kompatibilitás) ---
alias docker='podman'
alias docker-compose='podman-compose'
export DOCKER_HOST='unix:///run/user/$(id -u)/podman/podman.sock'
export CONTAINERS_REGISTRIES_CONF='/etc/containers/registries.conf'
# --- End Podman Beállítások ---
EOF
)

    if [[ -f "$BASHRC_FILE" ]]; then
        if ! grep -q "alias docker=podman" "$BASHRC_FILE" 2>/dev/null; then
            echo -e "\n$bashrc_addition" >> "$BASHRC_FILE"
            chown "$CURRENT_USER:$CURRENT_USER" "$BASHRC_FILE"
            print_status "success" "Aliasok és DOCKER_HOST hozzáadva a $BASHRC_FILE fájlhoz"
        else
            print_status "info" "Aliasok már léteznek a $BASHRC_FILE fájlban"
        fi
    else
        print_status "warning" "A $BASHRC_FILE fájl nem létezik, aliasok nem lettek hozzáadva"
    fi

    # Rootless Podman beállítása
    setup_rootless_podman "$CURRENT_USER"

    # Teszt futtatása
    print_status "highlight" "Rootless Teszt Futtatása"
    print_status "info" "Teszt futtatása 'hello-world' képpel..."
    if run_as_user "$CURRENT_USER" "podman pull hello-world && podman run --rm hello-world"; then
        print_status "success" "Hello-world teszt sikeres! 🎉 A Podman működik."
    else
        print_status "error" "Hello-world teszt sikertelen. Ellenőrizze a hibaüzeneteket."
    fi
}

# 2. Cockpit és Podman komponens telepítése
install_cockpit() {
    draw_header
    echo -e "${YELLOW}2. ${BOLD}COCKPIT ÉS PODMAN KOMPONENS TELEPÍTÉSE${NC}"
    echo "---------------------------------------------------------"
    
    local cockpit_packages=("cockpit" "cockpit-podman" "cockpit-storaged")
    check_package_availability "${cockpit_packages[@]}"
    
    print_status "info" "Cockpit és kapcsolódó csomagok telepítése..."
    apt install -y "${cockpit_packages[@]}"
    print_status "success" "Cockpit telepítve"

    # Cockpit szolgáltatás indítása
    print_status "info" "Cockpit szolgáltatás indítása és engedélyezése..."
    systemctl enable cockpit.socket --now
    print_status "success" "Cockpit socket engedélyezve és elindítva"
    
    # Tűzfal beállítása (ha installed)
    if command -v ufw &>/dev/null; then
        ufw allow 9090/tcp comment "Cockpit Web Console"
        print_status "success" "Tűzfal szabály hozzáadva a Cockpithoz (9090 port)"
    fi

    local ip_address
    ip_address=$(hostname -I | awk '{print $1}')
    
    print_status "highlight" "Cockpit Elérés"
    echo "  🌐 Nyissa meg a böngészőjében a címet:"
    echo -e "  ${CYAN}${UNDERLINE}https://${ip_address}:9090${NC}"
    echo "  🔐 Használja a rendszer bejelentkezési adatait."
}

# 3. Konténerek listázása
list_containers() {
    draw_header
    echo -e "${YELLOW}3. ${BOLD}KONTÉNER LISTÁZÁS (Root & Rootless)${NC}"
    echo "---------------------------------------------------------"
    
    set_user_context
    
    print_status "highlight" "Root Konténerek (podman ps -a)"
    if podman ps -a; then
        :
    else
        print_status "warning" "Nem található root konténer, vagy a Podman nincs megfelelően telepítve."
    fi
    
    echo ""
    print_status "highlight" "Rootless Konténerek (${CURRENT_USER} - podman ps -a)"
    if run_as_user "$CURRENT_USER" "podman ps -a"; then
        :
    else
        print_status "warning" "Nem található rootless konténer, vagy a Podman socket nem fut."
    fi
}

# 4. Tisztítás/Karbantartás funkció
cleanup() {
    draw_header
    echo -e "${YELLOW}4. ${BOLD}PODMAN RENDSZER KARBANTARTÁS (PRUNE)${NC}"
    echo "---------------------------------------------------------"
    
    set_user_context
    
    print_status "warning" "Ez a művelet visszavonhatatlanul eltávolítja az ÖSSZES nem használt konténert, képet és kötetet a ${CURRENT_USER} felhasználónál."
    read -r -p "Biztosan folytatja? (y/N): " response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_status "info" "Karbantartás futtatása..."
        if run_as_user "$CURRENT_USER" "podman system prune -f"; then
            print_status "success" "Karbantartás befejezve. Hely felszabadítva! 🧹"
        else
            print_status "error" "Karbantartás sikertelen."
        fi
    else
        print_status "info" "Karbantartás megszakítva."
    fi
}

# 5. Aliasok/Socket Aktíválás funkció
activate_aliases() {
    draw_header
    echo -e "${YELLOW}5. ${BOLD}ALIASOK ÉS SOCKET AKTIVÁLÁS ÚTMUTATÓ${NC}"
    echo "---------------------------------------------------------"
    
    [[ -z "$CURRENT_USER" ]] && set_user_context

    print_status "highlight" "Beállítások Érvényesítése"
    print_status "info" "A beállítások azonnali érvényesítéséhez a ${BOLD}$CURRENT_USER${NC}${BLUE} felhasználóként:"
    echo "  1. 🔄 Indítson egy ${BOLD}új terminált${NC} VAGY"
    echo -e "  2. 💻 Futtassa: ${CYAN}source $BASHRC_FILE${NC}"
    echo ""

    print_status "highlight" "Podman Socket (Rootless) Ellenőrzése"
    if run_as_user_systemd "$CURRENT_USER" "systemctl --user status podman.socket --no-pager --lines=5"; then
        print_status "success" "Podman socket ${BOLD}aktív és fut${NC}."
    else
        print_status "error" "Podman socket inaktív. Kérjük, használja a 6. opciót a javításhoz."
    fi
}

# 6. Docker kompatibilitás ellenőrzése és javítása
check_docker_compat() {
    draw_header
    echo -e "${YELLOW}6. ${BOLD}DOCKER KOMPATIBILITÁS ELLENŐRZÉSE ÉS JAVÍTÁSA${NC}"
    echo "---------------------------------------------------------"
    
    set_user_context

    print_status "highlight" "1. Aliasok és Környezeti Változók Ellenőrzése"
    local alias_ok=true
    
    if grep -q "alias docker=podman" "$BASHRC_FILE" 2>/dev/null && grep -q "export DOCKER_HOST=" "$BASHRC_FILE" 2>/dev/null; then
        print_status "success" "Aliasok és DOCKER_HOST beállítva."
    else
        print_status "error" "Aliasok/DOCKER_HOST HIÁNYZIK. Kérjük, futtassa az 1. opciót a javításhoz."
        alias_ok=false
    fi
    echo ""

    print_status "highlight" "2. Podman Rootless Socket Javítás"
    if run_as_user_systemd "$CURRENT_USER" "systemctl --user is-active podman.socket" &>/dev/null; then
        print_status "success" "A podman.socket ${BOLD}aktív${NC}."
    else
        print_status "warning" "A podman.socket ${RED}INAKTÍV${NC}. Megkíséreljük a javítást..."
        
        if loginctl enable-linger "$CURRENT_USER" && \
           run_as_user_systemd "$CURRENT_USER" "systemctl --user enable podman.socket --now"; then
            print_status "success" "Socket sikeresen elindítva és engedélyezve."
        else
            print_status "error" "Socket indítása sikertelen. Kérem manuális ellenőrzést: systemctl --user status podman.socket"
            return 1
        fi
    fi
    echo ""

    print_status "highlight" "3. Docker API Teszt (Socket Működése)"
    if run_as_user "$CURRENT_USER" "export DOCKER_HOST=unix:///run/user/\$(id -u)/podman/podman.sock && podman info > /dev/null 2>&1"; then
        print_status "success" "Docker kompatibilitás teszt ${BOLD}sikeres${NC}. A Podman API működik."
    else
        print_status "error" "Docker kompatibilitási hiba. Az API hívás sikertelen."
        print_status "info" "Ellenőrizze a jogosultságokat: ls -la /run/user/\$(id -u $CURRENT_USER)/podman/"
        return 1
    fi
}

# 7. Rendszer állapot jelentés
system_report() {
    draw_header
    echo -e "${YELLOW}7. ${BOLD}RENDSZER ÁLLAPOT JELENTÉS${NC}"
    echo "---------------------------------------------------------"
    
    [[ -z "$CURRENT_USER" ]] && set_user_context

    print_status "highlight" "Rendszer & Podman Állapot"
    check_podman_version
    echo "  OS: $(lsb_release -d | cut -f2-)"
    
    echo "  Linger állapot ($CURRENT_USER): ${BOLD}$(loginctl show-user "$CURRENT_USER" -p Linger --value)${NC}"
    
    echo "  Cockpit: $(systemctl is-active cockpit.socket &>/dev/null && echo -e "${GREEN}✅ Aktív${NC}" || echo -e "${RED}❌ Inaktív${NC}")"
    
    if run_as_user_systemd "$CURRENT_USER" "systemctl --user is-active podman.socket" &>/dev/null; then
        echo "  Podman Socket: ${GREEN}✅ Aktív${NC}"
    else
        echo "  Podman Socket: ${RED}❌ Inaktív${NC}"
    fi

    print_status "highlight" "Konténer Összefoglaló"
    local root_containers
    local user_containers
    root_containers=$(podman ps -a --format "{{.Names}}" 2>/dev/null | wc -l)
    user_containers=$(run_as_user "$CURRENT_USER" "podman ps -a --format '{{.Names}}'" 2>/dev/null | wc -l)

    echo "  Root konténerek (összes): ${BOLD}$root_containers${NC}"
    echo "  User konténerek (összes): ${BOLD}$user_containers${NC}"

    print_status "highlight" "Lemez Kihasználtság"
    df -h /var/lib/containers 2>/dev/null || df -h /home 2>/dev/null | grep -E 'Filesystem|home'
}

# Menü megjelenítése és fő ciklus
show_menu() {
    while true; do
        draw_header
        echo -e "${CYAN}${BOLD}Válasszon egy opciót a Podman kezeléséhez:${NC}"
        echo "---------------------------------------------------------"
        echo -e " ${GREEN}${BOLD}TELEPÍTÉS & ALAPOK${NC}"
        echo -e " 1) ⚙️  Podman Telepítés és Rootless Beállítás"
        echo -e " 2) 🌐 Cockpit és Podman Komponens Telepítése"
        echo "---------------------------------------------------------"
        echo -e " ${GREEN}${BOLD}KEZELÉS & KARBANTARTÁS${NC}"
        echo -e " 3) 📋 Konténerek Listázása (Root & Rootless)"
        echo -e " 4) 🧹 Rendszer Karbantartás (prune)"
        echo "---------------------------------------------------------"
        echo -e " ${GREEN}${BOLD}DIAGNOSZTIKA & SEGÉDLETEK${NC}"
        echo -e " 5) 💡 Aliasok/Socket Aktíválás Útmutató"
        echo -e " 6) 🔍 Docker Kompatibilitás Ellenőrzése és Javítása"
        echo -e " 7) 📊 Rendszer Állapot Jelentés"
        echo "---------------------------------------------------------"
        echo -e " 8) 🚪 ${RED}${BOLD}Kilépés${NC}"
        echo "---------------------------------------------------------"
        
        read -r -p "Választás [1-8]: " choice
        
        case "$choice" in
            1) main_setup ;;
            2) install_cockpit ;;
            3) list_containers ;;
            4) cleanup ;;
            5) activate_aliases ;;
            6) check_docker_compat ;;
            7) system_report ;;
            8) 
                print_status "info" "Viszlát! 👋"
                exit 0 
                ;;
            *) 
                print_status "error" "Érvénytelen választás ($choice), kérjük, próbálja újra (1-8)"
                ;;
        esac
        
        echo ""
        read -r -p "Nyomjon Enter-t a folytatáshoz..."
    done
}

# --- Fő program indulása ---
main() {
    check_root_privileges
    show_menu
}

# Handler a CTRL+C megnyomásához
trap 'echo ""; print_status "info" "Script megszakítva"; exit 0' INT

# Program indítása
main "$@"

#!/bin/bash

#================================================================================
# Bilingual SNMP Setup Script for Debian 13 (Trixie) - CORRECTED VERSION 2.1
# Kétnyelvű SNMP Beállító Szkript Debian 13-hoz - JAVÍTOTT VERZIÓ 2.1
#
# Target Monitoring Systems: Observium & LibreNMS
# Cél Monitorozó Rendszerek: Observium & LibreNMS
#
# Author: Citk
# Verzió: 2.1
#================================================================================

# --- Color Codes / Színkódok ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Language Strings / Nyelvi Változók ---

# English
en_script_must_be_run_as_root="This script must be run as root. Please use 'sudo'."
en_updating_packages="Updating package lists..."
en_installing_snmp="Installing SNMP daemon and common tools..."
en_install_failed="Failed to install SNMP packages. Aborting."
en_install_success="SNMP packages installed successfully."
en_starting_config="Starting SNMP configuration..."
en_prompt_monitor_ip="Enter the IP address of your Observium/LibreNMS server: "
en_prompt_community="Enter a secure SNMP Community String (e.g., 'Str0ngP@ssw0rd'): "
en_prompt_location="Enter the system's physical location (e.g., 'Server Room A'): "
en_prompt_contact="Enter the system administrator's email: "
en_backing_up_conf="Backing up the original configuration file to /etc/snmp/snmpd.conf.bak..."
en_creating_new_conf="Creating a new configuration file for Observium/LibreNMS..."
en_restarting_service="Restarting the SNMP service..."
en_config_success="SNMP configuration completed successfully!"
en_local_test_header="--- Performing Local SNMP Test ---"
en_local_test_desc="This test queries the system name using the community string you configured.\nIf successful, you will see the hostname of this machine."
en_local_test_command="Command: ${GREEN}snmpwalk -v2c -c YOUR_COMMUNITY_STRING localhost sysName.0${NC}"
en_prompt_test_community="Please enter the community string you configured to run the test: "
en_local_test_success="Local test successful! The SNMP agent is responding correctly."
en_local_test_failed="Local test failed. Please check the following:"
en_local_test_failed_1="- Is the snmpd service running? (Check with 'systemctl status snmpd')"
en_local_test_failed_2="- Did you enter the correct community string?"
en_local_test_failed_3="- Check the system log for errors: 'journalctl -u snmpd'"
en_remote_test_header="--- Testing from your Monitoring Server ---"
en_remote_test_desc="The final step is to test the connection from your Observium or LibreNMS server.\nThis ensures that firewalls are not blocking the connection."
en_remote_test_step1="1. SSH into your Observium/LibreNMS server."
en_remote_test_step2="2. Run the following command, replacing the IP and community string:"
en_remote_test_command="   snmpwalk -v2c -c ${YELLOW}YOUR_COMMUNITY_STRING${NC} ${GREEN}IP_OF_THIS_SERVER${NC} .1.3.6.1.2.1.1.1.0"
en_remote_test_success_cond="If the command returns the Linux kernel version, the connection is working perfectly."
en_remote_test_fail_cond="If it times out, you likely have a firewall issue. Ensure that UDP port 161 is open\non this server and on any network firewalls between this server and your monitoring host."
en_menu_title="SNMP Configuration Script for Debian 13"
en_menu_subtitle="For Observium & LibreNMS"
en_menu_prompt="Please select an option:"
en_menu_opt1="Full Installation & Configuration (Recommended)"
en_menu_opt2="Configure SNMP (if already installed)"
en_menu_opt3="Test SNMP Locally"
en_menu_opt4="Show Remote Test Instructions"
en_menu_opt5="Exit"
en_menu_choice="Enter your choice [1-5]: "
en_invalid_option="Invalid option. Please try again."

# Hungarian
hu_script_must_be_run_as_root="Ezt a szkriptet root jogosultsággal kell futtatni. Kérlek, használj 'sudo'-t."
hu_updating_packages="Csomaglisták frissítése..."
hu_installing_snmp="SNMP démon és a szükséges eszközök telepítése..."
hu_install_failed="Az SNMP csomagok telepítése sikertelen. A szkript leáll."
hu_install_success="Az SNMP csomagok sikeresen telepítve."
hu_starting_config="SNMP konfiguráció megkezdése..."
hu_prompt_monitor_ip="Adja meg az Observium/LibreNMS szerver IP címét: "
hu_prompt_community="Adjon meg egy biztonságos SNMP Community Stringet (pl. 'Er0sJ3l5z0'): "
hu_prompt_location="Adja meg a rendszer fizikai helyét (pl. 'Gépház A'): "
hu_prompt_contact="Adja meg a rendszergazda e-mail címét: "
hu_backing_up_conf="Eredeti konfigurációs fájl biztonsági mentése a /etc/snmp/snmpd.conf.bak helyre..."
hu_creating_new_conf="Új konfigurációs fájl létrehozása az Observium/LibreNMS számára..."
hu_restarting_service="SNMP szolgáltatás újraindítása..."
hu_config_success="Az SNMP konfigurálása sikeresen befejeződött!"
hu_local_test_header="--- Helyi SNMP Teszt Elvégzése ---"
hu_local_test_desc="Ez a teszt a beállított community string segítségével lekérdezi a rendszer nevét.\nSikeres esetben a gép hosztnevét fogja látni."
hu_local_test_command="Parancs: ${GREEN}snmpwalk -v2c -c AZ_ÖN_COMMUNITY_STRINGJE localhost sysName.0${NC}"
hu_prompt_test_community="Kérjük, adja meg a teszthez a beállított community stringet: "
hu_local_test_success="A helyi teszt sikeres! Az SNMP ügynök megfelelően válaszol."
hu_local_test_failed="A helyi teszt sikertelen. Kérjük, ellenőrizze a következőket:"
hu_local_test_failed_1="- Fut az snmpd szolgáltatás? (Ellenőrzés: 'systemctl status snmpd')"
hu_local_test_failed_2="- A helyes community stringet adta meg?"
hu_local_test_failed_3="- Ellenőrizze a rendszer naplófájljait hibákért: 'journalctl -u snmpd'"
hu_remote_test_header="--- Tesztelés a Monitorozó Szerverről ---"
hu_remote_test_desc="Az utolsó lépés a kapcsolat tesztelése az Observium vagy LibreNMS szerveréről.\nEz biztosítja, hogy a tűzfalak nem blokkolják a kapcsolatot."
hu_remote_test_step1="1. Lépjen be SSH-n az Observium/LibreNMS szerverére."
hu_remote_test_step2="2. Futtassa a következő parancsot, behelyettesítve az IP címet és a community stringet:"
hu_remote_test_command="   snmpwalk -v2c -c ${YELLOW}AZ_ÖN_COMMUNITY_STRINGJE${NC} ${GREEN}ENNEK_A_SZERVERNEK_AZ_IP_CÍME${NC} .1.3.6.1.2.1.1.1.0"
hu_remote_test_success_cond="Ha a parancs visszaadja a Linux kernel verzióját, a kapcsolat tökéletesen működik."
hu_remote_test_fail_cond="Ha időtúllépést kap, valószínűleg tűzfal probléma áll fenn. Győződjön meg róla, hogy az UDP 161-es port nyitva van\nezen a szerveren, valamint a két gép közötti hálózati tűzfalakon is."
hu_menu_title="SNMP Beállító Szkript Debian 13-hoz"
hu_menu_subtitle="Observium & LibreNMS rendszerekhez"
hu_menu_prompt="Kérjük, válasszon egy lehetőséget:"
hu_menu_opt1="Teljes telepítés és konfigurálás (Ajánlott)"
hu_menu_opt2="SNMP konfigurálása (ha már telepítve van)"
hu_menu_opt3="Helyi SNMP teszt"
hu_menu_opt4="Távoli tesztelési útmutató"
hu_menu_opt5="Kilépés"
hu_menu_choice="Adja meg a választását [1-5]: "
hu_invalid_option="Érvénytelen opció. Kérjük, próbálja újra."

# --- Function to check for root privileges ---
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}${script_must_be_run_as_root}${NC}"
        exit 1
    fi
}

# --- Function to install SNMP packages ---
install_snmp() {
    echo -e "${GREEN}${updating_packages}${NC}"
    apt-get update -y >/dev/null 2>&1
    echo -e "${GREEN}${installing_snmp}${NC}"
    apt-get install snmpd snmp -y >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}${install_failed}${NC}"
        exit 1
    fi
    echo -e "${GREEN}${install_success}${NC}"
}

# --- Function to configure SNMP ---
configure_snmp() {
    echo -e "${YELLOW}${starting_config}${NC}"

    read -p "${prompt_monitor_ip}" MONITOR_IP
    read -p "${prompt_community}" COMMUNITY_STRING
    read -p "${prompt_location}" SYS_LOCATION
    read -p "${prompt_contact}" SYS_CONTACT

    echo -e "${GREEN}${backing_up_conf}${NC}"
    mv /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.bak

    echo -e "${GREEN}${creating_new_conf}${NC}"
    cat > /etc/snmp/snmpd.conf << EOF
#==============================================================================
# /etc/snmp/snmpd.conf
# Configuration for Observium & LibreNMS
#==============================================================================
agentAddress udp:161
sysLocation    "$SYS_LOCATION"
sysContact     "$SYS_CONTACT"
rocommunity $COMMUNITY_STRING $MONITOR_IP
extend .1.3.6.1.4.1.2021.7890.1 distro /usr/bin/distro
EOF

    echo -e "${GREEN}${restarting_service}${NC}"
    systemctl restart snmpd
    systemctl enable snmpd

    echo -e "${GREEN}${config_success}${NC}"
}

# --- Function to test SNMP locally ---
test_snmp_local() {
    echo -e "${YELLOW}${local_test_header}${NC}"
    echo -e "${local_test_desc}"
    echo -e "${local_test_command}"
    
    read -p "${prompt_test_community}" TEST_COMMUNITY
    
    snmpwalk -v2c -c "$TEST_COMMUNITY" localhost sysName.0
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${local_test_success}${NC}"
    else
        echo -e "${RED}${local_test_failed}${NC}"
        echo "${local_test_failed_1}"
        echo "${local_test_failed_2}"
        echo "${local_test_failed_3}"
    fi
}

# --- Function to explain remote testing ---
explain_remote_test() {
    echo -e "${YELLOW}${remote_test_header}${NC}"
    echo -e "${remote_test_desc}"
    echo ""
    echo -e "${GREEN}${remote_test_step1}${NC}"
    echo -e "${GREEN}${remote_test_step2}${NC}"
    echo ""
    echo -e "${remote_test_command}"
    echo ""
    echo -e "${remote_test_success_cond}"
    echo -e "${remote_test_fail_cond}"
}

# --- Main Menu ---
main_menu() {
    clear
    echo "======================================================="
    echo "  ${menu_title}             "
    echo "  ${menu_subtitle}                            "
    echo "======================================================="
    echo "${menu_prompt}"
    echo "1. ${menu_opt1}"
    echo "2. ${menu_opt2}"
    echo "3. ${menu_opt3}"
    echo "4. ${menu_opt4}"
    echo "5. ${menu_opt5}"
    echo "-------------------------------------------------------"
    read -p "${menu_choice}" choice

    case $choice in
        1) install_snmp; configure_snmp ;;
        2) configure_snmp ;;
        3) test_snmp_local ;;
        4) explain_remote_test ;;
        5) exit 0 ;;
        *) echo -e "${RED}${invalid_option}${NC}" ;;
    esac
}

# --- Language Selection ---
select_language() {
    clear
    echo "Please select a language / Kérjük, válasszon nyelvet:"
    echo ""
    echo "1. English"
    echo "2. Magyar (Hungarian)"
    echo ""
    read -p "Enter your choice [1-2]: " lang_choice

    case $lang_choice in
        1) LANG_PREFIX="en" ;;
        2) LANG_PREFIX="hu" ;;
        *) echo "Invalid selection. Defaulting to English."; LANG_PREFIX="en"; sleep 2 ;;
    esac

    # Dynamically create GLOBAL variables for the selected language
    for var in $(compgen -v ${LANG_PREFIX}_); do
        var_name=$(echo $var | sed "s/^${LANG_PREFIX}_//")
        # The '-g' flag makes the variable global, accessible outside this function. THIS IS THE FIX.
        declare -g "$var_name"="${!var}"
    done
}


# --- Script Execution ---
check_root
select_language
main_menu

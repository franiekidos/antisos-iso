#!/usr/bin/env bash
# AntisOS Netsetup - Pre-desktop network configuration with refresh
# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

echo -e "${BLUE}=== AntisOS Network Setup ===${RESET}"

# Detect virtualization
if systemd-detect-virt -q; then
    echo -e "${YELLOW}VM detected → preferring virtual ethernet.${RESET}"
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "ens|eth|enp" | head -n1)
else
    echo -e "${YELLOW}Bare metal detected → checking ethernet first.${RESET}"
    IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -E "ens|eth|enp" | head -n1)
fi

# Try Ethernet first
if [ -n "$IFACE" ]; then
    echo -e "${GREEN}Ethernet interface found: $IFACE${RESET}"
    echo -e "${YELLOW}Trying DHCP...${RESET}"
    ip link set "$IFACE" up
    if dhclient "$IFACE" &>/dev/null; then
        echo -e "${GREEN}Connected via Ethernet!${RESET}"
        exit 0
    else
        echo -e "${RED}Ethernet DHCP failed.${RESET}"
    fi
else
    echo -e "${RED}No Ethernet interface detected.${RESET}"
fi

# Wi-Fi loop
while true; do
    echo -e "${BLUE}Scanning Wi-Fi networks...${RESET}"
    iwctl station wlan0 scan
    SSID_LIST=$(iwctl station wlan0 get-networks | awk 'NR>4 {print $1}' | grep -v '^[^a-zA-Z0-9]')

    if [ -z "$SSID_LIST" ]; then
        echo -e "${RED}No Wi-Fi networks found.${RESET}"
        echo "Options: [M]anual SSID / [R]efresh scan / [Q]uit"
        read -rp "> " CHOICE
        case "$CHOICE" in
            [Mm]) 
                read -rp "Enter SSID manually: " SSID ;;
            [Rr]) continue ;;
            [Qq]) exit 1 ;;
            *) echo "Invalid option"; continue ;;
        esac
    else
        echo -e "${YELLOW}Available networks:${RESET}"
        select SSID in $SSID_LIST "Manual Entry" "Refresh Scan" "Quit"; do
            case "$SSID" in
                "Manual Entry")
                    read -rp "Enter SSID: " SSID
                    break
                    ;;
                "Refresh Scan")
                    continue 2
                    ;;
                "Quit")
                    exit 1
                    ;;
                *)
                    [ -n "$SSID" ] && break
                    ;;
            esac
        done
    fi

    read -rp "Enter Wi-Fi password (leave empty for open): " -s PASSWORD
    echo

    if [ -n "$PASSWORD" ]; then
        iwctl --passphrase "$PASSWORD" station wlan0 connect "$SSID"
    else
        iwctl station wlan0 connect "$SSID"
    fi

    sleep 3
    if ping -c1 archlinux.org &>/dev/null; then
        echo -e "${GREEN}Wi-Fi connected to $SSID!${RESET}"
        exit 0
    else
        echo -e "${RED}Failed to connect to $SSID.${RESET}"
        echo "Try again..."
    fi
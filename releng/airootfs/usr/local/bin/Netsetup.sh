#!/bin/bash
# AntisOS Smart Network Connector
# Requires: iwd, dialog, systemd

virt=$(systemd-detect-virt)

if [ "$virt" != "none" ]; then
    dialog --msgbox "AntisOS detected a virtual machine ($virt).

Ethernet will auto-configure.
Wi-Fi setup skipped." 12 60
    exit 0
fi

# Check Ethernet on bare metal
for iface in $(ls /sys/class/net/ | grep -E 'en|eth'); do
    if [ -f /sys/class/net/$iface/carrier ]; then
        if [ "$(cat /sys/class/net/$iface/carrier)" = "1" ]; then
            dialog --msgbox "Ethernet cable detected on $iface.

AntisOS will auto-configure networking." 12 60
            exit 0
        fi
    fi
done

# If no Ethernet → Wi-Fi
tmpfile=$(mktemp)

iwctl station wlan0 scan
sleep 2
networks=$(iwctl station wlan0 get-networks | awk 'NR>4 {print $1}')

if [ -z "$networks" ]; then
    dialog --msgbox "No Wi-Fi networks found!" 8 40
    exit 1
fi

dialog --menu "Select a Wi-Fi network:" 20 60 10 $(
    for net in $networks; do echo "$net" "$net"; done
) 2>"$tmpfile"

choice=$(cat "$tmpfile")

if [ -n "$choice" ]; then
    dialog --insecure --passwordbox "Enter Wi-Fi password for $choice:" 10 50 2>"$tmpfile"
    pass=$(cat "$tmpfile")
    iwctl station wlan0 connect "$choice" -P "$pass" && \
        dialog --msgbox "Connected to $choice!" 8 40 || \
        dialog --msgbox "Failed to connect to $choice." 8 40
fi
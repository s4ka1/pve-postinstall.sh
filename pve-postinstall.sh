#!/bin/bash

# Copyright (c) 2024 Sergio Sánchez Martínez
# Author: Sergio Sánchez Martínez (l0rdsergio)

declare -x FRAME
declare -x FRAME_INTERVAL

set_spinner() {
  FRAME=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  FRAME_INTERVAL=0.1
}

show_spinner() {
  local pid=$1
  local i=0
  
  echo -ne "\033[?25l"

  while ps -p $pid &>/dev/null; do
    echo -ne "\\r\033[1;34m[${FRAME[i]}]\033[0m $2                    "
    i=$(( (i+1) % ${#FRAME[@]} ))
    sleep $FRAME_INTERVAL
  done

  echo -ne "\033[?25h"
  echo -ne "\\r\033[1;32m[OK]\033[0m $2                    \n"
}

cancel_execution() {
  echo -e "\n\033[1;31m[!] Execution has been cancelled\033[0m"
  exit 1
}

trap 'cancel_execution' INT

set_spinner
clear
echo -e "\033[1;33m
    ____ _    ________   ____             __     ____           __        ____
   / __ \ |  / / ____/  / __ \____  _____/ /_   /  _/___  _____/ /_____ _/ / /
  / /_/ / | / / __/    / /_/ / __ \/ ___/ __/   / // __ \/ ___/ __/ __  / / /
 / ____/| |/ / /___   / ____/ /_/ (__  ) /_   _/ // / / (__  ) /_/ /_/ / / /
/_/     |___/_____/  /_/    \____/____/\__/  /___/_/ /_/____/\__/\__,_/_/_/ 
                                                                         
                                                by Sergio Sánchez Martínez
                         
\033[0m"

echo -n "[/] Correcting Proxmox VE Sources... "
{
cat <<EOF >/etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' >/etc/apt/apt.conf.d/no-bookworm-firmware.conf
} &
show_spinner $! "Corrected Proxmox VE Sources"

echo -n "[/] Disabling 'pve-enterprise' repository... "
{
rm -f /etc/apt/sources.list.d/pve-enterprise.list > /dev/null 2>&1
} &
show_spinner $! "Disabled 'pve-enterprise' repository"

echo -n "[/] Enabling 'pve-no-subscription' repository... "
{
cat <<EOF >/etc/apt/sources.list.d/pve-install-repo.list
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
} &
show_spinner $! "Enabled 'pve-no-subscription' repository"

echo -n "[/] Correcting 'ceph package repositories'... "
{
cat <<EOF >/etc/apt/sources.list.d/ceph.list
deb http://download.proxmox.com/debian/ceph-quincy bookworm enterprise
deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
deb http://download.proxmox.com/debian/ceph-reef bookworm enterprise
deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
} &
show_spinner $! "Corrected 'ceph package repositories'"

echo -n "[/] Adding 'pvetest' repository and set disabled... "
{
cat <<EOF >/etc/apt/sources.list.d/pvetest-for-beta.list
# deb http://download.proxmox.com/debian/pve bookworm pvetest
EOF
} &
show_spinner $! "Added 'pvetest' repository"

echo -n "[/] Disabling subscription alert ... "
{
echo "DPkg::Post-Invoke { \"dpkg -V proxmox-widget-toolkit | grep -q '/proxmoxlib\.js$'; if [ \$? -eq 1 ]; then { echo 'Removing subscription nag from UI...'; sed -i '/.*data\.status.*{/{s/\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; }; fi\"; };" >/etc/apt/apt.conf.d/no-nag-script
apt --reinstall install proxmox-widget-toolkit &>/dev/null
} &
show_spinner $! "Disabled subscription alert"

echo -n "[/] Customizing the shell appearance... "
{
echo 'export PS1="\[\e[31m\][\[\e[m\]\[\e[32m\]\u\[\e[m\]\[\e[31m\]@\[\e[m\]\[\e[33m\]\h\[\e[m\] \[\e[36;41m\]\A\[\e[m\] \[\e[31m\]-\[\e[m\] \[\e[34;40m\]\w\[\e[m\]\[\e[31m\]]\[\e[m\]\[\e[33m\]\\$\[\e[m\]\[\e[33m\]:\[\e[m\] "' >> ~/.bashrc 
} &
show_spinner $! "Customized shell appearance"

echo -n "[/] Updating Proxmox VE (Be patient!)... "
{
apt-get update -y > /dev/null 2>&1
apt-get -y dist-upgrade > /dev/null 2>&1
} &
show_spinner $! "Updating Proxmox VE"

reboot_choice="Y"
read -p "Reboot Proxmox VE now? (recommended) [Y/n]: " -r reboot_choice
reboot_choice=${reboot_choice:-Y}
if [[ $reboot_choice == [Yy]* ]]; then
  echo -ne "\033[1;35m[✔] Rebooting Proxmox VE... \n\033[0m"
  reboot
else
  echo -e "\033[1;33m[✔] All tasks have been completed successfully\033[0m"
fi
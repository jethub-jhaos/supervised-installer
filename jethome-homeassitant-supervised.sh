#!/bin/bash

set -e

############################################################################################################
# Variables 2

SCRIPT="jethub-homeassistant-installer"

LANG=C
LC_ALL=en_US.UTF-8
LANGUAGE=C
DEBIAN_FRONTEND=noninteractive
APT_LISTCHANGES_FRONTEND=none

export LANG LC_ALL LANGUAGE DEBIAN_FRONTEND APT_LISTCHANGES_FRONTEND

finish=1693429200

now=$(date +%s)
if [ $now -lt $finish ]
then
    SUPPORTED_OS=(
        "bullseye"
        "bookworm"
        )
else
    SUPPORTED_OS=(
        "bookworm"
        )
fi

HOME_ASSISTANT_MACHINE="qemuarm-64"

############################################################################################################
# Functions

function print_info() {
    echo -e "\e[1;34m[${SCRIPT}] INFO:\e[0m $1"
}

function print_error() {
    echo -e "\e[1;31m[${SCRIPT}] ERROR:\e[0m $1"
}

############################################################################################################
# Main

echo "####################################################################"
echo " JetHome JetHub Home Assistant Installer"
echo ""
echo " Official site: https://jethome.ru"
echo " Documentation: https://jethome.ru/wiki"
echo " Telegram community: https://t.me/jethomeru"
echo "####################################################################"


# Check if script run as root
if [ "$EUID" -ne 0 ]
  then print_error "Please run as root!"
  exit
fi

CURRENT_OS=$(lsb_release -d | sed -E 's/Description:\s+//')

#
# Check if distro is supported
#
SUPPORTED=0
for distro in "${SUPPORTED_OS[@]}"
do
  if [[ "${CURRENT_OS}" =~ "${distro}" ]]; then
      SUPPORTED=1
  fi
done

if [[ "${SUPPORTED}" == "0" ]]; then
    print_error "This script is not supported on this OS: '$CURRENT_OS'"
    # print supported distros
    print_error "Supported OS:"
    for distro in "${SUPPORTED_OS[@]}"
    do
        print_error "    $distro"
    done
    print_error "Please installs supported distro from http://fw.jethome.ru and try again"
    exit 1
else
    print_info "Current distro: '$CURRENT_OS' - supported"
fi

#
# Updating
#
print_info "Updating system..."

apt update -y
apt upgrade -y

print_info "Updating system done"


#
# Check 'extraargs=systemd.unified_cgroup_hierarchy=false' exists in /boot/armbianEnv.txt, add if not exists
#
if grep -q "extraargs=systemd.unified_cgroup_hierarchy=false" /boot/armbianEnv.txt; then
    print_info "Already modified: /boot/armbianEnv.txt"
else
    print_info "Modifying /boot/armbianEnv.txt"
    echo "extraargs=systemd.unified_cgroup_hierarchy=false" >> /boot/armbianEnv.txt
fi

#
# Iptables
#
#print_info "Installing iptables..."

#apt install -y iptables
#update-alternatives --set iptables /usr/sbin/iptables-legacy
#update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

#print_info "Installing iptables done"

#
# Docker
#
if [ -x "$(command -v docker)" ]; then
    print_info "Docker already installed"
else
    print_info "Installing docker..."
    curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
    if [[ -n "${SUDO_USER}" ]] ; then 
      usermod -aG docker $SUDO_USER
    fi
    print_info "Installing docker done"
fi

#
# Installing dependencies
#
#print_info "Installing dependencies..."

#apt install -y jq wget curl udisks2 libglib2.0-bin network-manager dbus apparmor systemd-journal-remote

#print_info "Installing dependencies done"

#
# Installing os-agent
#
#print_info "Installing os-agent..."

#curl -s https://api.github.com/repos/home-assistant/os-agent/releases/latest | grep "browser_download_url.*aarch64\.deb" | cut -d : -f 2,3 | tr -d \" | wget -O os-agent-aarch64.deb -i -
#dpkg -i os-agent-aarch64.deb
#rm -f os-agent-aarch64.deb

#print_info "Installing os-agent done"

#
# Installing Home Assistant Supervised
#
print_info "Installing Home Assistant Supervised (machine: ${HOME_ASSISTANT_MACHINE})..."

export MACHINE="${HOME_ASSISTANT_MACHINE}"

#wget https://github.com/home-assistant/supervised-installer/releases/latest/download/homeassistant-supervised.deb
#dpkg -i homeassistant-supervised.deb
#rm -f homeassistant-supervised.deb
apt install -y homeassistant-supervised

print_info "Home Assistant will be installed in tens of minutes..."
print_info "You can use 'journalctl -f' to see installation progress"

exit 0
#!/bin/bash

set -e

############################################################################################################
# Variables

SCRIPT="jethub-homeassistant-installer"

LANG=C
LC_ALL=en_US.UTF-8
LANGUAGE=C
DEBIAN_FRONTEND=noninteractive
APT_LISTCHANGES_FRONTEND=none
TIMEOUT=1200
REINSTALL=0

HOME_ASSISTANT_MACHINE="qemuarm-64"

export LANG LC_ALL LANGUAGE DEBIAN_FRONTEND APT_LISTCHANGES_FRONTEND HOME_ASSISTANT_MACHINE

SUPPORTED_OS=(
        "bookworm"
        )

############################################################################################################
# Functions

function print_info() {
    echo -e "\e[1;34m[${SCRIPT}] INFO:\e[0m $1"
}

function print_request() {
    echo -n -e "\e[1;34m[${SCRIPT}] INFO:\e[0m $1"
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
# Check for HA installed
#
if [[ -f /usr/sbin/hassio-supervisor ]]; then
    print_request "Home Assistant already installed. Reinstall Y/N? "

    # Read the answer from the keyboard
    read -r answer

    # Check if the answer is one of the specified options
    if [[ "$answer" != "Y" && "$answer" != "y" && "$answer" != "Д" && "$answer" != "д" ]]; then
        print_error "Operation cancelled."
        exit 1
    fi

    print_info "Remove old Home Assistant..."

    systemctl stop haos-agent > /dev/null 2>&1
    systemctl stop hassio-apparmor > /dev/null 2>&1
    systemctl stop hassio-supervisor > /dev/null 2>&1
    dpkg -r homeassistant-supervised > /dev/null 2>&1
    dpkg -r os-agent > /dev/null 2>&1
    docker ps | tail +2 | cut -d " " -f 1 | xargs -n 1 docker stop 
    docker ps | tail +2 | cut -d " " -f 1 | xargs -n 1 docker stop 
    sleep 5
    docker system prune -a -f --volumes > /dev/null 2>&1
    docker system prune -a -f --volumes > /dev/null 2>&1
    #touch /root/.ha_prepared

    print_info "Remove old Home Assistant done"
    REINSTALL=1

fi


if [[ ! -f /root/.ha_prepared ]]; then

    #
    # Docker
    #
    if [ -x "$(command -v docker)" ]; then
        print_info "Docker already installed"
    else
        print_info "Installing docker..."
        #curl -fsSL get.docker.com -o get-docker.sh && sh get-docker.sh
        apt-get update
        apt-get install ca-certificates curl gnupg
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg

        # Add the repository to Apt sources:
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        apt-get update

#Workaround for bug in docker 5.25 version
#ii  docker-buildx-plugin               0.11.2-1~debian.12~bookworm                     arm64        Docker Buildx cli plugin.
#ii  docker-ce                          5:24.0.7-1~debian.12~bookworm                   arm64        Docker: the open-source application container engine
#ii  docker-ce-cli                      5:24.0.7-1~debian.12~bookworm                   arm64        Docker CLI: the open-source application container engine
#ii  docker-compose-plugin              2.21.0-1~debian.12~bookworm                     arm64        Docker Compose (V2) plugin for the Docker CLI.

        apt-get install -y --allow-downgrades \
        docker-compose-plugin=2.21.0-1~debian.12~bookworm \
        docker-ce-cli=5:24.0.7-1~debian.12~bookworm \
        docker-buildx-plugin=0.11.2-1~debian.12~bookworm \
        docker-ce=5:24.0.7-1~debian.12~bookworm \
        docker-ce-rootless-extras=5:24.0.7-1~debian.12~bookworm

        if [[ -n "${SUDO_USER}" ]] ; then 
        usermod -aG docker "$SUDO_USER"
        fi
        rm -f get-docker.sh
        print_info "Installing docker done"
    fi

    #
    # Updating system
    #
    print_info "Updating system..."

    apt-get update -y
    apt-get dist-upgrade -y

    print_info "Updating system done"

    #
    # Installing dependencies
    #

    print_info "Installing dependencies..."

    apt-get install -y jq wget curl udisks2 libglib2.0-bin network-manager dbus apparmor systemd-resolved systemd-journal-remote nfs-common cifs-utils

    print_info "Installing dependencies done"

    #
    # Check 'extraargs=systemd.unified_cgroup_hierarchy=false' exists in /boot/armbianEnv.txt, add if not exists
    #
    print_info "Check CGROUP config..."
    if grep -q "extraargs=systemd.unified_cgroup_hierarchy=false" /boot/armbianEnv.txt; then
        print_info "... Already modified: /boot/armbianEnv.txt"
    else
        print_info "... Modifying /boot/armbianEnv.txt"
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

    touch /root/.ha_prepared
    if [[ "${REINSTALL}" == "0" ]]; then
        touch /var/run/reboot-required
        print_info "Preparation done. Please reboot and run this script again"
        print_info "curl https://raw.githubusercontent.com/jethub-homeassistant/supervised-installer/jethome-homeassistant-supervised/jethome-homeassitant-supervised.sh | sudo bash"
    else
        print_info "Reinstall pre-check done."
    fi
fi

if [[ -f /var/run/reboot-required ]]; then
    print_error "Reboot required. Please reboot and run this script again"
    exit 1
fi

#
# Install HA packages
#

export MACHINE="${HOME_ASSISTANT_MACHINE}"

#
# - Installing os-agent
#
print_info "Installing os-agent..."

apt-get install -y os-agent

systemctl enable haos-agent
systemctl start haos-agent

sleep 1

print_info "Installing os-agent done"

print_info "Fix os-release for Debian 12"

sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Debian GNU\/Linux 12 (bookworm)"/' /etc/os-release 

#
# - Installing Home Assistant Supervised
#
print_info "Installing Home Assistant Supervised (machine: ${MACHINE})..."

MACHINE="qemuarm-64" apt-get install -y homeassistant-supervised

print_info "Home Assistant will be installed in tens of minutes"
print_info "Please wait for supervisor up (timeout 1200 sec)..."

rm -f /root/.ha_prepared

i=0

while ! docker ps |grep -q hassio_supervisor;
do
    sleep 5
    i=$((i+5))
    if (( i % 30 == 0 )); then
        echo "Waiting for Home Assistant supervisor is up $i secs....." >&2    #DEBUG
    fi
    if [ -n "${TIMEOUT}" ]; then
        if [ $i -gt "${TIMEOUT}" ]; then
            print_error "Timeout waiting for supervisor. Please check internet connection and try again"
            exit 5
        fi
    fi
done

print_info "Installing Home Assistant Supervised done. Install Home Assistant core"

i=0

while ! curl http://127.0.0.1:8123 >/dev/null 2>&1
do
    sleep 5
    i=$((i+5))
    if (( i % 30 == 0 )); then
        echo "Waiting for Home Assistant core connection $i secs....." >&2    #DEBUG
    fi
    if [ -n "${TIMEOUT}" ]; then
        if [ $i -gt "${TIMEOUT}" ]; then
            print_error "Timeout waiting for landingpage. Please check internet connection and try again"
            exit 6
        fi
    fi
done

print_info "Home Assistant landingpage is up. Install Home Assistant core"

i=0

# Loop to wait for 'homeassistant' without 'landing'
while true; do
    if docker ps | grep -q " homeassistant" && ! docker ps | grep -q "landing"; then
        break
    else
        sleep 5
        i=$((i+5))
        # Every 15 seconds, display a waiting message
        if (( i % 30 == 0 )); then
            echo "Waiting for Home Assistant core up $i secs....." >&2    #DEBUG
        fi
        if [ -n "${TIMEOUT}" ]; then
            if [ $i -gt "${TIMEOUT}" ]; then
                print_error "Timeout waiting for Home Assistant Core. Please check internet connection and try again"
                exit 6
            fi
        fi
    fi
done

print_info "Home Assistant up and running. Please reboot for avoid 'supervisor in unprivileged' error"
print_request "Try access http://"
read -r _{,} _ _ _ _ ip _ < <(ip r g 1.0.0.0) ; echo "$ip:8123"

exit 0

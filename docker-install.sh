#!/bin/bash
#shellcheck shell=bash external-sources=false disable=SC1090,SC2164
# DOCKER-INSTALL.SH -- Installation script for the Docker infrastructure on a Raspbian or Ubuntu system
# Usage: source <(curl -s https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
#
# Copyright 2021-2023 Ramon F. Kolb (kx1t)- licensed under the terms and conditions
# of the MIT license. The terms and conditions of this license are included with the Github
# distribution of this package.


clear
cat << "EOM"
            __/\__
           `==/\==`               ____             _               ___           _        _ _
 ____________/__\____________    |  _ \  ___   ___| | _____ _ __  |_ _|_ __  ___| |_ __ _| | |
/____________________________\   | | | |/ _ \ / __| |/ / _ \ '__|  | || '_ \/ __| __/ _` | | |
  __||__||__/.--.\__||__||__     | |_| | (_) | (__|   <  __/ |     | || | | \__ \ || (_| | | |
 /__|___|___( >< )___|___|__\    |____/ \___/ \___|_|\_\___|_|    |___|_| |_|___/\__\__,_|_|_|
           _/`--`\_
jgs       (/------\)
EOM
echo
echo "Welcome to the Docker Infrastructure installation script"
echo "We will help you install Docker and Docker-compose."
echo "and then help you with your configuration."
echo
echo "Note - this scripts makes use of \"sudo\" to install Docker."
echo "If you haven't added your current login to the \"sudoer\" list,"
echo "you may be asked for your password at various times during the installation."
echo
echo "This script strongly prefers a \"standard\" OS setup of Debian Buster/Bullseye/Bookworm, including variations like"
echo "Raspberry Pi OS, DietPi, or Ubuntu. It uses 'apt-get' and 'wget' to get started, and assumes access to"
echo "the standard package repositories".
echo
echo "If you have an old device usign Debian Stretch, we will try to install the software, but be WARNED that"
echo "Docker for Stretch is deprecated and is no longer actively supported by the Docker community."
echo

if [[ "$EUID" == 0 ]]; then
    echo "STOP -- you are running this as an account with superuser privileges (ie: root), but should not be. It is best practice to NOT install Docker services as \"root\"."
    echo "Instead please log out from this account, log in as a different non-superuser account, and rerun this script."
    echo "If you are unsure of how to create a new user, you can learn how here: https://linuxize.com/post/how-to-create-a-sudo-user-on-debian/"
    echo ""
    exit 1
fi

echo "This script was last updated on $(curl -sSL -X GET -H "Cache-Control: no-cache" https://api.github.com/repos/sdr-enthusiasts/docker-install/commits??path=docker-install.sh | jq -r '.[0].commit.committer.date')"
echo ""
read -p "Press ENTER to start."

deps=()
deps+=(apt-transport-https)
deps+=(ca-certificates)
deps+=(curl)
deps+=(gnupg2)
deps+=(slirp4netns)
deps+=(software-properties-common)
deps+=(uidmap)
deps+=(w3m)
deps+=(jq)
deps+=(git)
deps+=(rtl-sdr)
deps+=(chrony)
if grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1; then deps+=(uhubctl); fi
if ! grep "bookworm" /etc/os-release >/dev/null 2>&1; then deps+=(netcat); else deps+=(netcat-openbsd); fi

echo -n "First we will update your system and install some dependencies ... "
sudo apt-get update -q -y >/dev/null
sudo apt-get upgrade -q -y
sudo apt-get install -q -y ${deps[@]} >/dev/null

if ! grep sudo /etc/group | grep -e ":${USER}$" >/dev/null 2>&1; then
  echo "We'll start by adding your login name, \"${USER}\", to \"sudoers\". This will enable you to use \"sudo\" without having to type your password every time."
  echo "You may be asked to enter your password a few times below. We promise, this is the last time."
  echo
  read -p "Should we do this now? If you choose \"no\", you can always to it later by yourself [Y/n] > " -n 1 text
  if [[ "${text,,}" != "n" ]]
  then
      echo
      echo -n "Adding user \"${USER}\" to the 'sudo' group... "
      sudo usermod -aG sudo "${USER}"
      echo "done!"
      echo -n "Ensuring that user \"${USER}\" can run 'sudo' without entering a password... "
      echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-"${USER}"-privileges >/dev/null
      sudo chmod 0440 /etc/sudoers.d/90-"${USER}"-privileges
      echo "done!"
      echo "If it continues to ask for a password below, do the following:"
      echo "- press CTRL-c to stop the execution of this install script"
      echo "- type \"exit\" to log out from your machine"
      echo "- log in again"
      echo "- re-run this script using the same command as you did before"
      echo
  fi
else
  echo "Your account, \"${USER}\", is already part of the \"sudo\" group. Great!"
fi

echo "We will now continue and install Docker."
echo -n "Checking for an existing Docker installation... "
if which docker >/dev/null 2>&1
then
    echo "found! Skipping Docker installation"
else
    echo "not found!"
    echo "Installing docker, each step may take a while:"
    echo -n "Getting docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    echo "Installing Docker... "
    sudo sh get-docker.sh
    echo "Docker installed -- configuring docker..."
    sudo usermod -aG docker "${USER}"
    sudo mkdir -p /etc/docker
    sudo chmod a+rwx /etc/docker
    cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "local",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    sudo chmod u=rw,go=r /etc/docker/daemon.json
    if ! grep -e "/usr/bin:" -e "/usr/bin$" <<< "$PATH" >/dev/null 2>&1; then
      #shellcheck disable=SC2016
      echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
      export PATH=/usr/bin:$PATH
    fi
    
    sudo systemctl restart docker.service docker.socket 
    echo "Now let's run a test container:"
    if sudo docker run --rm hello-world
    then
      echo ""
      echo "Did you see the \"Hello from Docker! \" message above?"
      echo "If yes, all is good! If not, press CTRL-C and trouble-shoot."
      echo ""
      echo "Note - in order to run your containers as user \"${USER}\" (and without \"sudo\"), you should"
      echo "log out and log back into your Raspberry Pi once the installation is all done."
      echo ""
      read -p "Press ENTER to continue."
    else
      echo ""
      echo "Something went wrong -- this will probably be fixed with a system reboot"
      echo "You can continue to install all the other things using this script, and then reboot the system."
      echo "After the reboot, give this command to check that everything works well:"
      echo ""
      echo "docker run --rm hello-world"
      echo ""
      read -p "Press ENTER to continue."
    fi
fi

echo -n "Checking for Docker Compose installation... "
if which docker-compose >/dev/null 2>&1
then
    echo "found! No need to install..."
elif docker compose version >/dev/null 2>&1
then
    echo "Docker Compose plugin found. Creating an alias to it for \"docker-compose \"..."
    echo "alias docker-compose=\"docker compose\"" >> ~/.bash_aliases
    source ~/.bash_aliases
else
    echo "not found!"
    echo "Installing Docker compose... "
    sudo apt install -y docker-compose-plugin
    if docker compose version
    then
      echo "Docker compose was installed successfully. You can use either \"docker compose\" or \"docker-compose\", they are aliases of each other"
    else
      echo "Docker-compose was not installed correctly - you may need to do this manually."
    fi
fi

# Now make sure that libseccomp2 >= version 2.4. This is necessary for Bullseye-based containers
# This is often an issue on Buster and Stretch-based host systems with 32-bits Rasp Pi OS installed pre-November 2021.
# The following code checks and corrects this - see also https://github.com/fredclausen/Buster-Docker-Fixes
echo "Checking that your system has a current version of libseccomp2."
echo "This is necessary to run Bullseye and later based containers on a Buster or Stretch based system..."
OS_VERSION="$(sed -n 's/\(^\s*VERSION_CODENAME=\)\(.*\)/\2/p' /etc/os-release)"
[[ "$OS_VERSION" == "" ]] && OS_VERSION="$(sed -n 's/^\s*VERSION=.*(\(.*\)).*/\1/p' /etc/os-release)"
OS_VERSION=${OS_VERSION^^}
LIBVERSION_MAJOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p')"
LIBVERSION_MINOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p')"

if (( LIBVERSION_MAJOR < 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR < 4 )) && [[ "${OS_VERSION}" == "BUSTER" ]]
then
  echo "libseccomp2 needs updating. Please wait while we do this."
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138 0E98404D386FA1D9 6ED0E7B82643E131
  echo "deb http://deb.debian.org/debian buster-backports main" | sudo tee -a /etc/apt/sources.list.d/buster-backports.list
  sudo apt update -y
  sudo apt install -y -q -t buster-backports libseccomp2
elif (( LIBVERSION_MAJOR < 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR < 4 )) && [[ "${OS_VERSION}" == "STRETCH" ]]
then
  echo "libseccomp2 needs updating. Please wait while we do this."
  INSTALL_CANDIDATE=$(curl -qsL http://ftp.debian.org/debian/pool/main/libs/libseccomp/ |w3m -T text/html -dump | sed -n 's/^.*\(libseccomp2_2.5.*armhf.deb\).*/\1/p' | sort | tail -1)
  curl -qsL -o /tmp/"${INSTALL_CANDIDATE}" http://ftp.debian.org/debian/pool/main/libs/libseccomp/${INSTALL_CANDIDATE}
  sudo dpkg -i /tmp/"${INSTALL_CANDIDATE}" && rm -f /tmp/"${INSTALL_CANDIDATE}"
else
  echo "Your system already has an acceptable version of libseccomp2. Doing some final checks on that now..."
fi
# Now make sure all went well
LIBVERSION_MAJOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p')"
LIBVERSION_MINOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p')"
if (( LIBVERSION_MAJOR > 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR >= 4 ))
then
   echo "Your system (now) uses libseccomp2 version $(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p')."
else
    echo "Something went wrong. Your system is using libseccomp2 v$(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p'), and it needs to be v2.4 or greater for the ADSB containers to work properly."
    echo "Please follow these instructions to fix this after this install script finishes: https://github.com/fredclausen/Buster-Docker-Fixes"
    read -p "Press ENTER to continue."
fi

echo
echo "Do you want to prepare the system for use with any of the RTL-SDR / ADS-B containers?"
echo "Examples of these include the collection of containers maintained by SDR-Enthusiasts group:"
echo "Ultrafeeder, Tar1090, Readsb-ProtoBuf, Acarshub, PlaneFence, PiAware, RadarVirtuel, FR24, other feeders, etc."
echo "It's safe to say YES to this question and continue unless you are using a DVB-T stick to watch digital television."
echo
read -p "Please choose yes or no [Y/n] > " -n 1 text
if [[ "${text,,}" != "n" ]]
then
    echo
    tmpdir=$(mktemp -d)
    pushd "$tmpdir" >/dev/null || exit
        echo -n "Getting the latest UDEV rules... "
        # First install the UDEV rules for RTL-SDR dongles
        sudo -E "$(which bash)" -c "curl -sL -o /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules"
        # Next, exclude the drivers so the dongles stay accessible
        # Please keep the list in this order and add any additional ones to the BOTTOM. 
        BLOCKED_MODULES=()
        BLOCKED_MODULES+=("rtl2832_sdr")
        BLOCKED_MODULES+=("dvb_usb_rtl2832u")
        BLOCKED_MODULES+=("dvb_usb_rtl28xxu")
        BLOCKED_MODULES+=("dvb_usb_v2")
        # BLOCKED_MODULES+=("8192cu")
        BLOCKED_MODULES+=("r820t")
        BLOCKED_MODULES+=("rtl2830")
        BLOCKED_MODULES+=("rtl2832")
        BLOCKED_MODULES+=("rtl2838")
        # BLOCKED_MODULES+=("rtl8192cu")
        # BLOCKED_MODULES+=("rtl8xxxu")
        BLOCKED_MODULES+=("dvb_core")
        echo -n "Excluding and unloading any competing RTL-SDR drivers... "
        UNLOAD_SUCCESS=true
        for module in "${BLOCKED_MODULES[@]}"
        do
            if ! grep -q "$module" /etc/modprobe.d/exclusions-rtl2832.conf
            then
              sudo -E "$(which bash)" -c "echo blacklist $module >>/etc/modprobe.d/exclusions-rtl2832.conf"
              sudo -E "$(which bash)" -c "echo install $module /bin/false >>/etc/modprobe.d/exclusions-rtl2832.conf"
              sudo -E "$(which bash)" -c "modprobe -r $module 2>/dev/null" || UNLOAD_SUCCESS=false
            fi
        done
        # Rebuild module dependency database factoring in blacklists
        which depmod >/dev/null 2>&1 && sudo depmod -a  >/dev/null 2>&1 || UNLOAD_SUCCESS=false
        # On systems with initramfs, this needs to be updated to make sure the exclusions take effect:
        which update-initramfs >/dev/null 2>&1 && sudo update-initramfs -u  >/dev/null 2>&1 || true 

        if [[ "${UNLOAD_SUCCESS}" == false ]]; then
          echo "INFO: Although we've successfully excluded any competing RTL-SDR drivers, we weren't able to unload them. This will remedy itself when you reboot your system after the script finishes."
        fi
    popd >/dev/null
    # Check tmpdir is set and not null before attempting to remove it
    if [[ -z "$tmpdir" ]]; then
      rm -rf "$tmpdir" >/dev/null 2>&1
    fi
fi
echo "Making sure commands will persist when the terminal closes..."
sudo loginctl enable-linger "$(whoami)" >/dev/null 2>&1
#
# The following prevents DHCPCD based systems from trying to assign IP addresses to each of the Docker containers.
# Note that this is not needed or available if the system uses DHCPD instead of DHCPCD.
if [[ -f /etc/dhcpcd.conf ]] && ! grep "denyinterfaces veth\*" /etc/dhcpcd.conf >/dev/null 2>&1
then
  echo -n "Excluding veth interfaces from dhcp. This will prevent problems if you are connected to the internet via WiFi when running many Docker containers... "
  sudo sh -c 'echo "denyinterfaces veth*" >> /etc/dhcpcd.conf'
  sudo systemctl restart dhcpcd.service
  echo "done!"
fi

# Add some aliases to localhost in `/etc/hosts`. This will speed up recreation of images with docker-compose
if ! grep localunixsocket /etc/hosts >/dev/null 2>&1
then
  echo "Speeding up the recreation of containers when using docker-compose..."
  sudo sed -i 's/^\(127.0.0.1\s*localhost\)\(.*\)/\1\2 localunixsocket localunixsocket.local localunixsocket.home/g' /etc/hosts
fi

echo "Adding some handy aliases to your bash shell. You can find them by typing \"cat ~/.bash_aliases\""
curl -sSL "https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/bash_aliases" >> ~/.bash_aliases
echo "source ~/.bash_aliases" >> ~/.bashrc
source ~/.bash_aliases

echo "Adding a crontab entry to ensure your system stays clean"
file="$(mktemp)"
crontab -l > "$file"
echo '0 3 * * * /usr/bin/docker system prune -af >/dev/null 2>&1' >> "$file"
cat "$file" | crontab -
rm -f "$file"

echo "--------------------------------"
echo "We're done! Here are some final messages, read them carefully:"
echo "We've installed these packages, and we think they may be useful for you in the future. So we will leave them installed:"
echo "git, rtl-sdr"
echo "If you don't want them, feel free to uninstall them using this command:"
echo "sudo apt-get remove git rtl-sdr"
echo ""
echo "To make sure that everything works OK, you should reboot your machine."
echo ""
echo "WARNING - if you are connected remotely to a Raspberry Pi (via SSH or VNC)"
echo "make sure you unplug any externally powered USB devices or hubs before rebooting"
echo "because these may cause your Raspberry Pi to get stuck in the \"off\" state!"
echo ""
echo "Once rebooted, you are ready to go! For safety reasons, we won't do the reboot for you, but you can do it manually by typing:"
echo ""
echo "sudo reboot"
echo ""
echo "That's all -- thanks for using our docker-install script. You are now ready to create docker-compose.yml files and start running containers!"

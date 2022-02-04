#!/bin/bash
# DOCKER-INSTALL.SH -- Installation script for the Docker infrastructure on a Raspbian or Ubuntu system
# Usage: source <(curl -s https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
#
# Copyright 2021, 2022, Ramon F. Kolb (kx1t)- licensed under the terms and conditions
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
echo "This script assumes a \"standard\" OS setup of Debian Buster or later, including variations like"
echo "Raspberry Pi OS or Ubuntu. It uses \'apt-get\' and \'wget\' to get started, and assumes access to"
echo "the standard package repositories".
echo
read -p "Press ENTER to start, CTRL-C to abort, or \"?\" to get help on how to add your login to the \"sudoers\" list > " text
if [[ "$text" == "?" ]]
then
    echo
    echo "Adding your login name, \"${USER}\", to \"sudoers\" will enable you to use \"sudo\" without having to type your password every time."
    echo "You may be asked to enter your password a few times below. We promise, this is the last time."
    echo
    read -p "Should we do this now? If you choose \"no\", you can always to it later by yourself [Y/n] > " -n 1 text
    if [[ "${text,,}" != "n" ]]
    then
        echo
        echo -n "Adding user \"${USER}\" to the \'sudo\' group... "
        sudo usermod -aG sudo "${USER}"
        echo "done!"
        echo -n "Ensuring that user \"${USER}\" can run \'sudo\' without entering a password... "
        echo "${USER} ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-"${USER}"-privileges >/dev/null
        sudo chmod 0440 /etc/sudoers.d/90-"${USER}"-privileges
        echo "done!"
        echo
        echo "You should be ready to go now. If it continues to ask for a password below, do the following:"
        echo "- press CTRL-c to stop the execution of this install script"
        echo "- type \"exit\" to log out from your machine"
        echo "- log in again"
        echo "- re-run this script using the same command as you did before"
        echo
    fi
fi
echo "Starting the installation of Docker."
echo -n "Checking for an existing Docker installation... "
if which docker >/dev/null 2>&1
then
    echo "found! Skipping Docker installation"
else
    echo "not found!"
    echo "Installing docker, each step may take a while:"
    echo -n "Updating repositories... "
    sudo apt-get update -qq -y >/dev/null && sudo apt-get upgrade -q -y
    echo -n "Ensuring dependencies are installed... "
    sudo apt-get install -qq -y curl uidmap slirp4netns >/dev/null
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
    echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
    export PATH=/usr/bin:$PATH

    sudo service docker restart
    echo "Now let's run a test container:"
    sudo docker run --rm hello-world
    echo
    echo "Did you see the \"Hello from Docker! \" message above?"
    echo "If yes, all is good! If not, press CTRL-C and trouble-shoot."
    echo
    echo "Note - in order to run your containers as user \"${USER}\" (and without \"sudo\"), you should"
    echo "log out and log back into your Raspberry Pi once the installation is all done."
    echo
    read -p "Press ENTER to continue."
fi

echo -n "Checking for Docker-compose installation... "
if which docker-compose >/dev/null 2>&1
then
    echo "found! No need to install..."
else
    echo "not found!"
    echo "Installing Docker-compose... "

    # Do a bunch of prep work
    DC_ARCHS=("darwin-aarch64")
    DC_ARCHS+=("darwin-x86_64")
    DC_ARCHS+=("linux-aarch64")
    DC_ARCHS+=("linux-armv6")
    DC_ARCHS+=("linux-armv7")
    DC_ARCHS+=("linux-s390x")
    DC_ARCHS+=("linux-x86_64")

    OS_NAME="$(uname -s)"
    OS_NAME="${OS_NAME,,}"
    ARCH_NAME="$(uname -m)"
    ARCH_NAME="${ARCH_NAME,,}"
    [[ "${ARCH_NAME:0:5}" == "armv6" ]] && ARCH_NAME="armv6"
    [[ "${ARCH_NAME:0:5}" == "armv7" ]] && ARCH_NAME="armv7"
    [[ "${ARCH_NAME:0:5}" == "armhf" ]] && ARCH_NAME="armv7"
    [[ "${ARCH_NAME:0:5}" == "armel" ]] && ARCH_NAME="armv6"

    if [[ ! "${DC_ARCHS[*]}" =~ "${OS_NAME}-${ARCH_NAME}" ]]
    then
      echo "Cannot install Docker-Compose for your system \"${OS_NAME}-${ARCH_NAME}\" because there is no suitable install candidate."
      echo "You may be able to install it manually or compile from source; see https://github.com/docker/compose/releases"
    else
      sudo curl -L "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-${OS_NAME}-${ARCH_NAME}" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
      [[ -d "/usr/local/lib/docker/cli-plugins" ]] && sudo ln -s /usr/local/bin/docker-compose /usr/local/lib/docker/cli-plugins
      [[ -d "/usr/lib/docker/cli-plugins" ]] && sudo ln -s /usr/local/bin/docker-compose /usr/lib/docker/cli-plugins
      [[ -d "/usr/local/libexec/docker/cli-plugins" ]] && sudo ln -s /usr/local/bin/docker-compose /usr/local/libexec/docker/cli-plugins
      [[ -d "/usr/libexec/docker/cli-plugins" ]] && sudo ln -s /usr/local/bin/docker-compose /usr/libexec/docker/cli-plugins
      if docker-compose version
      then
        echo "Docker-compose was installed successfully."
      else
        echo "Docker-compose was not installed correctly - you may need to do this manually."
      fi
    fi
fi

# Now make sure that libseccomp2 >= version 2.4. This is necessary for Bullseye-based containers
# This is often an issue on Buster-based host systems with 32-bits Rasp Pi OS installed pre-November 2021.
# The following code checks and corrects this - see also https://github.com/fredclausen/Buster-Docker-Fixes
OS_VERSION="$(sed -n 's/\(^\s*VERSION_CODENAME=\)\(.*\)/\2/p' /etc/os-release)"
OS_VERSION=${OS_VERSION^^}
LIBVERSION_MAJOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p')"
LIBVERSION_MINOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p')"
if (( LIBVERSION_MAJOR < 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR < 5 )) && [[ "${OS_VERSION}" == "BUSTER" ]]
then
  echo "libseccomp2 needs updating. Please wait while we do this."
  sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC 648ACFD622F3D138
  echo "deb http://deb.debian.org/debian buster-backports main" | sudo tee -a /etc/apt/sources.list.d/buster-backports.list
  sudo apt update
  sudo apt install -y -q -t buster-backports libseccomp2
  # Now make sure all went well
  LIBVERSION_MAJOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p')"
  LIBVERSION_MINOR="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1 | sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p')"
  if (( LIBVERSION_MAJOR > 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR >= 4 ))
  then
	   echo "Upgrade successful. Your system now uses libseccomp2 version $(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p')."
  else
	    echo "Something went wrong. Your system is using libseccomp2 v$(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p'), and it needs to be v2.4 or greater for the ADSB containers to work properly."
      echo "Please follow these instructions to fix this after this install script finishes: https://github.com/fredclausen/Buster-Docker-Fixes"
	    read -p "Press ENTER to continue."
  fi
else
  echo "Your system is based on Debian ${OS_VERSION} and has libseccomp2 v$(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p'),"
  echo "No need to upgrade to a newer version!"
fi

echo
echo "Do you want to prepare the system for use with any of the RTL-SDR / ADS-B containers?"
echo "Examples of these include the collection of containers maintained by @MikeNye,"
echo "Tar1090, Readsb-ProtoBuf, Acarshub, PlaneFence, PiAware, RadarVirtuel, FR24, other feeders, etc."
echo "It\'s safe to say YES to this question and continue, unless you are using a DVB-T stick to watch digital television."
echo
read -p "Press ENTER to continue, or CTRL-C to abort"
echo
tmpdir=$(mktemp -d)
pushd "$tmpdir" >/dev/null || exit
    echo -n "Getting the latest RTL-SDR packages... "
    sudo apt-get install -qq -y git rtl-sdr >/dev/null
    echo -n "Getting the latest UDEV rules... "
    # First install the UDEV rules for RTL-SDR dongles
    sudo -E $(which bash) -c "curl -sL -o /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules"
    # Next, blacklist the drivers so the dongles stay accessible
    echo -n "Blacklisting any competing RTL-SDR drivers... "
    sudo -E $(which bash) -c "echo blacklist rtl2832 >/etc/modprobe.d/blacklist-rtl2832.conf"
    sudo -E $(which bash) -c "echo blacklist dvb_usb_rtl28xxu >>/etc/modprobe.d/blacklist-rtl2832.conf"
    sudo -E $(which bash) -c "echo blacklist rtl2832_sdr >>/etc/modprobe.d/blacklist-rtl2832.conf"
    sudo -E $(which bash) -c "echo blacklist rtl8xxxu >>/etc/modprobe.d/blacklist-rtl2832.conf"
    sudo -E $(which bash) -c "echo blacklist rtl2838 >>/etc/modprobe.d/blacklist-rtl2832.conf"

    # Unload any existing drivers, suppress any error messages that are displayed when the driver wasnt loaded:
    echo -n "Unloading any preloaded RTL-SDR drivers... ignore any error messages:"
    sudo -E $(which bash) -c "rmmod rtl2832_sdr 2>/dev/null"
    sudo -E $(which bash) -c "rmmod dvb_usb_rtl28xxu 2>/dev/null"
    sudo -E $(which bash) -c "rmmod rtl2832 2>/dev/null"
    sudo -E $(which bash) -c "rmmod rtl8xxxu 2>/dev/null"
    sudo -E $(which bash) -c "rmmod rtl2838 2>/dev/null"

popd >/dev/null
rm -rf "$tmpdir"

echo "Making sure commands will persist when the terminal closes..."
sudo loginctl enable-linger "$(whoami)"
if grep "denyinterfaces veth\*" /etc/dhcpcd.conf >/dev/null 2>&1
then
  echo -n "Excluding veth interfaces from dhcp... "
  sudo sh -c 'echo "denyinterfaces veth*" >> /etc/dhcpcd.conf'
  echo "done!"
fi

echo
echo "We\'ve installed these packages, and we think they may be useful for you in the future. So we will leave them installed:"
echo "git, rtl-sdr"
echo "If you don\'t want them, feel free to uninstall them using this command:"
echo "sudo apt-get remove git rtl-sdr"
echo ""
echo "To make sure that everything works OK, you should reboot your machine."
echo ""
echo "WARNING - if you are connected remotely to a Raspberry Pi (via SSH or VNC)"
echo "make sure you unplug any externally powered USB devices or hubs before rebooting"
echo "because these may cause your Raspberry Pi to get stuck in the \"off\" state!"
echo ""
echo "Once rebooted, you are ready to go!"
read -p "Press ENTER to reboot, or CTRL-C to abort"
sudo reboot

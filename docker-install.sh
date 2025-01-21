#!/bin/bash
#shellcheck shell=bash external-sources=false disable=SC1090,SC2015,SC2164,SC2128,SC2076
# DOCKER-INSTALL.SH -- Installation script for the Docker infrastructure on a Raspbian or Ubuntu system
# Usage: source <(curl -s https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
#
# Copyright 2021-2024 Ramon F. Kolb (kx1t)
#
# Licensed under the terms and conditions of the MIT license.
# https://github.com/sdr-enthusiasts/docker-install/main/LICENSE
#
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
# ------------------------------------------------------------------------------------------
# VARIABLE DEFINITIONS:
# These are the supported architectures for SDR-enthusiasts docker containers
# We will warn if the system reports a different architecture
#
# 28-Mar-2024 - note, in the future, we are considering removing armhf as supported architecture for the installation
#               because several of our containers no longer work on this architecture.
SUPPORTED_ARCH=(armhf)
SUPPORTED_ARCH+=(arm64)
SUPPORTED_ARCH+=(aarch64)
SUPPORTED_ARCH+=(amd64)
SUPPORTED_ARCH+=(x86_64)

#
# This is the list of applications that we want to have installed to ensure good working
# of the containerized SDR environment:
APT_INSTALLS=(apt-transport-https)
APT_INSTALLS+=(ca-certificates)
APT_INSTALLS+=(curl)
APT_INSTALLS+=(gnupg2)
APT_INSTALLS+=(slirp4netns)
APT_INSTALLS+=(software-properties-common)
APT_INSTALLS+=(uidmap)
APT_INSTALLS+=(w3m)
APT_INSTALLS+=(jq)
APT_INSTALLS+=(git)
APT_INSTALLS+=(rtl-sdr)
APT_INSTALLS+=(chrony)
if grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1; then APT_INSTALLS+=(uhubctl); fi
if ! grep "bookworm" /etc/os-release >/dev/null 2>&1; then APT_INSTALLS+=(netcat); else APT_INSTALLS+=(netcat-openbsd); fi
#
# This is the list of SDR modules/drivers that need to get excluded 
# Please keep the list in this order and add any additional ones to the BOTTOM
BLOCKED_MODULES=("rtl2832_sdr")
BLOCKED_MODULES+=("dvb_usb_rtl2832u")
BLOCKED_MODULES+=("dvb_usb_rtl28xxu")
BLOCKED_MODULES+=("dvb_usb_v2")
BLOCKED_MODULES+=("r820t")
BLOCKED_MODULES+=("rtl2830")
BLOCKED_MODULES+=("rtl2832")
BLOCKED_MODULES+=("rtl2838")
BLOCKED_MODULES+=("dvb_core")
#
# Recommended Debian version:
RECOMMENDED_DEBIAN=("12 (bookworm)")  # standard Debian version name. This is the one that will show as recommended
RECOMMENDED_DEBIAN+=("22.04") # Ubuntu current LTS release
RECOMMENDED_DEBIAN+=("23.04") # Ubuntu current normal release
RECOMMENDED_DEBIAN+=("23.10") # Ubuntu current normal release
#
# ------------------------------------------------------------------------------------------

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

Welcome to the Docker Infrastructure installation script. We will help you install Docker and Docker-compose
and then help you with your configuration.

This script is Copyright 2021-2024 Ramon F. Kolb (kx1t) and other contributors. It is maintained by the SDR-Enthusiasts Organization.
It is licensed under the terms and conditions of the MIT license.
https://github.com/sdr-enthusiasts/docker-install/main/LICENSE

Join us at https://discord.com/invite/mBRTWnjS3M where we can provide help and further support.

EOM

if ! which jq >/dev/null 2>&1 || ! which curl >/dev/null 2>&1; then
  echo "One moment while we install the minimally needed software (curl and jq) for the script to run. This will take 15-30 seconds (or longer on systems with very slow internet)"
  sudo bash -c "apt -qq update >/dev/null 2>&1 && apt -qq -y install curl jq >/dev/null 2>&1"
fi

echo "The script was last updated on $(date -d "$(curl -sSL -X GET -H "Cache-Control: no-cache" https://api.github.com/repos/sdr-enthusiasts/docker-install/commits??path=docker-install.sh | jq -r '.[0].commit.committer.date')")"
cat << "EOM"

Note - this script makes use of "sudo" to install Docker.
If you haven't added your current login to the "sudoer" list,
you may be asked for your password at various times during the installation.
EOM

if [[ "$EUID" == 0 ]]; then
    echo
    echo "STOP -- you are running this script using an account with superuser privileges (i.e., $USER). It is best practice to NOT install Docker services as \"$USER\" user."
    echo "Instead please log out from this account, log in as a different non-superuser account, and rerun this script."
    echo "If you are unsure of how to create a new user, you can learn how here: https://linuxize.com/post/how-to-create-a-sudo-user-on-debian/"
    echo
    exit 1
fi

os_recommended=false
if [[ -f /etc/os-release ]]; then 
  for os in "${RECOMMENDED_DEBIAN[@]}"; do 
    #shellcheck disable=SC2143
    if grep -q "$os" /etc/os-release; then
      os_recommended=true
      break
    fi
  done
fi

if [[ "$os_recommended" == false ]]; then
  echo
  echo "WARNING: This device isn't running the newest recommended version of the Debian Linux OS."
  if grep -q "stretch" /etc/os-release; then
    echo "This device appears to be running Debian 9 (\"Stretch\"), which has been End of Life (EOL) since June 2022 and is no longer actively supported by the community."
    echo "If you encounter issues, consider upgrading to Debian 11 (\"Bullseye\") or 12 (\"Bookworm\")."
    echo
    echo "We can try to install Docker anyway, but if you come across any issues, we unfortunately are unable to support you."
    echo "In that case, please upgrade your OS to Debian ${RECOMMENDED_DEBIAN[0]}."
  elif [[ -f /etc/os-release ]]; then
    echo "This device appears to be running Debian $(sed -n 's/^VERSION=\"\(.*\)\"$/\1/p' /etc/os-release 2>/dev/null). Although installation will probably work, we recommend upgrading your OS to Debian $RECOMMENDED_DEBIAN if possible."
  elif [[ -n "$MACHTYPE" ]]; then
    echo "This device appears to be running a non-Debian OS identified by $MACHTYPE. This script only works on DEBIAN operating systems as it uses Debian specific commands like \"apt\" and \"dpkg\"."
    echo "Aborting!"
    exit 99
  else 
    echo "This device appears to be running an unknown OS. This script relies on specific Debian commands commands like \"apt\" and \"dpkg\"."
    echo "As a result, the script will probably fail. You can try to continue, but we are unable to support you if any errors occur."
    echo "In that case, please upgrade your OS to Debian ${RECOMMENDED_DEBIAN[0]}, using for example to the latest version of DietPi, Raspberry Pi OS, Armbian, or Ubuntu."
  fi
  echo ""
  echo "This script strongly prefers a \"standard\" OS setup of Debian Buster/Bullseye/Bookworm, including variations like"
  echo "Raspberry Pi OS, DietPi, Armbian, or Ubuntu. It uses 'apt-get', 'dpkg', and 'wget' to get started,"
  echo "and assumes access to the standard package repositories."
  echo ""
  echo "If you are starting with a newly installed Linux build, we strongly suggest you to use"
  echo "the latest version of Debian (currently Debian ${RECOMMENDED_DEBIAN[0]})."
fi

# check if the current architecture is supported
#shellcheck disable=SC2076

ARCH="$(dpkg --print-architecture 2>/dev/null || echo "${MACHTYPE%%*-}")"
if [[ "$ARCH" == "arm" ]] && [[ "${MACHTYPE: -9}" == "gnueabihf" ]]; then ARCH="armhf"; fi
ARCH="${ARCH:-unknown}"

if [[ ! " ${SUPPORTED_ARCH[*]} " =~ " $ARCH " ]]; then
  echo
  echo "WARNING: Your system reports \"$ARCH\" as architecture."
  echo "         This is not supported by most of the SDR-Enthusiasts SDR-related containers."
  echo "         These only support the following architectures: ${SUPPORTED_ARCH[*]}."
  echo "         You can continue to use this script, but please note that you can't use this system with any of the SDR-Enthusiasts containers."
  echo
  echo -n "Press CTRL-C to abort. "
fi

if [[ "$ARCH" == "armhf" ]]; then
  echo
  echo "WARNING: Your system reports \"$ARCH\" as architecture."
  echo "         We will discontinue support for 32-bits ARM Linux in the near future. We strongly suggest you upgrade your machine, if possible,"
  echo "         to a 64-bit Debian Linux OS, such as DietPi, Ubuntu, or Raspberry Pi OS (64 bits)."
  echo "         You can continue to use this script, but please note that some of the SDR-Enthusiasts containers already no longer support $ARCH."
  echo
  echo -n "Press CTRL-C to abort. "
fi

# Before installing the files, remove the ones in the command line that have been marked with "no-xxx"
# For example, set "no-chrony" to omit Chrony from being installed.

#shellcheck disable=SC2199
if [[ -n "$@" ]]; then
  readarray -d ' ' -t argv <<< "$@"
  echo -n "The following applications will be excluded from the installation: " 
  for i in "${argv[@]}"; do
    i="${i,,}"             # make lowercase
    i="${i//[$'\t\r\n ']}" # strip any newlines, spaces, etc.
    if [[ "${i:0:3}" == "no-" ]]; then
      for j in "${!APT_INSTALLS[@]}"; do
        if [[ "${i:3}" == "${APT_INSTALLS[j]}" ]]; then
          echo -n "${APT_INSTALLS[j]} "
          unset "APT_INSTALLS[j]"
        fi
      done
    fi
  done
  echo
fi

read -r -p "Press ENTER to start."

echo -n "First we will update your system and install some dependencies ... "
sudo apt-get update -q -y >/dev/null
sudo apt-get upgrade -q -y
sudo apt-get install -q -y "${APT_INSTALLS[@]}" >/dev/null

if ! grep sudo /etc/group | grep -qe ":${USER}$"; then
  echo "We'll start by adding your login name, \"${USER}\", to \"sudoers\". This will enable you to use \"sudo\" without having to type your password every time."
  echo "You may be asked to enter your password a few times below. We promise, this is the last time."
  echo
  read -r -p "Should we do this now? If you choose \"no\", you can always to it later by yourself [Y/n] > " -n 1 text
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
    curl -fsSL https://get.docker.com | sudo sh
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
    if ! grep -qe "/usr/bin:" -e "/usr/bin$" <<< "$PATH"; then
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
      read -r -p "Press ENTER to continue."
    else
      echo ""
      echo "Something went wrong -- this will probably be fixed with a system reboot"
      echo "You can continue to install all the other things using this script, and then reboot the system."
      echo "After the reboot, give this command to check that everything works well:"
      echo ""
      echo "docker run --rm hello-world"
      echo ""
      read -r -p "Press ENTER to continue."
    fi
fi

echo "Adding some handy aliases to your bash shell. You can find them by typing \"cat ~/.sdre_aliases\""
curl -sSL "https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/bash_aliases" > ~/.sdre_aliases
grep -qs sdre_aliases ~/.bashrc || echo "source ~/.sdre_aliases" >> ~/.bashrc
source ~/.sdre_aliases

echo -n "Checking for Docker Compose installation... "
if which docker-compose >/dev/null 2>&1; then
    echo "found! No need to install..."
elif docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin found. Creating an alias to it for \"docker-compose \"..."
    echo "alias docker-compose=\"docker compose\"" >> ~/.sdre_aliases
    source ~/.sdre_aliases
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

if [[ "${OS_VERSION}" == "BUSTER" ]] ||  [[ "${OS_VERSION}" == "STRETCH" ]]; then
	LIBVERSION="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1)"
	LIBVERSION_MAJOR="$(sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p' <<< "$LIBVERSION")"
	LIBVERSION_MINOR="$(sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p' <<< "$LIBVERSION")"
	
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
	  INSTALL_CANDIDATE="$(curl -qsL http://ftp.debian.org/debian/pool/main/libs/libseccomp/ | w3m -T text/html -dump | sed -n 's/^.*\(libseccomp2_2.5.*armhf.deb\).*/\1/p' | sort | tail -1)"
	  curl -qsL -o /tmp/"${INSTALL_CANDIDATE}" http://ftp.debian.org/debian/pool/main/libs/libseccomp/"${INSTALL_CANDIDATE}"
	  sudo dpkg -i /tmp/"${INSTALL_CANDIDATE}" && rm -f /tmp/"${INSTALL_CANDIDATE}"
	else
	  echo "Your system already has an acceptable version of libseccomp2. Doing some final checks on that now..."
	fi
	# Now make sure all went well
	LIBVERSION="$(apt-cache policy libseccomp2 | grep -e libseccomp2: -A1 | tail -n1)"
	LIBVERSION_MAJOR="$(sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\1/p' <<< "$LIBVERSION")"
	LIBVERSION_MINOR="$(sed -n 's/.*:\s*\([0-9]*\).\([0-9]*\).*/\2/p' <<< "$LIBVERSION")"
	if (( LIBVERSION_MAJOR > 2 )) || (( LIBVERSION_MAJOR == 2 && LIBVERSION_MINOR >= 4 ))
	then
	   echo "Your system (now) uses libseccomp2 version $(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p')."
	else
	    echo "Something went wrong. Your system is using libseccomp2 v$(apt-cache policy libseccomp2|sed -n 's/\s*Installed:\s*\(.*\)/\1/p'), and it needs to be v2.4 or greater for the ADSB containers to work properly."
	    echo "Please follow these instructions to fix this after this install script finishes: https://github.com/fredclausen/Buster-Docker-Fixes"
	    read -r -p "Press ENTER to continue."
	fi
else
 	echo "Your system is not BUSTER or STRETCH based, so there should be no problem with libseccomp2."
fi

echo
echo "Do you want to prepare the system for use with any of the RTL-SDR / ADS-B containers?"
echo "Examples of these include the collection of containers maintained by SDR-Enthusiasts group:"
echo "Ultrafeeder, Tar1090, Readsb-ProtoBuf, Acarshub, PlaneFence, PiAware, RadarVirtuel, FR24, other feeders, etc."
echo "It's safe to say YES to this question and continue unless you are using a DVB-T stick to watch digital television."
echo
read -r -p "Please choose yes or no [Y/n] > " -n 1 text
if [[ "${text,,}" != "n" ]]; then
    echo
    echo -n "Getting the latest UDEV rules... "
    sudo mkdir -p -m 0755 /etc/udev/rules.d /etc/udev/hwdb.d
    # First install the UDEV rules for RTL-SDR dongles
    sudo -E "$(which bash)" -c "curl -sL -o /etc/udev/rules.d/rtl-sdr.rules https://raw.githubusercontent.com/wiedehopf/adsb-scripts/master/osmocom-rtl-sdr.rules"
    sudo -E "$(which bash)" -c "curl -sL -o /etc/udev/rules.d/dump978-fa.rules https://raw.githubusercontent.com/flightaware/dump978/master/debian/dump978-fa.udev"
    # Now install the UDEV rules for SDRPlay devices
    sudo -E "$(which bash)" -c "curl -sL -o /etc/udev/rules.d/66-mirics.rules https://raw.githubusercontent.com/sdr-enthusiasts/install-libsdrplay/main/66-mirics.rules"
    sudo -E "$(which bash)" -c "curl -sL -o /etc/udev/hwdb.d/20-sdrplay.hwdb https://raw.githubusercontent.com/sdr-enthusiasts/install-libsdrplay/main/20-sdrplay.hwdb"
    # make sure the permissions are set correctly
    sudo -E "$(which bash)" -c "chmod a+rX /etc/udev/rules.d /etc/udev/hwdb.d"
    sudo -E "$(which bash)" -c "chmod go+r /etc/udev/rules.d/* /etc/udev/hwdb.d/*"
    # Next, exclude the drivers so the dongles stay accessible
    echo -n "Excluding and unloading any competing RTL-SDR drivers... "
    UNLOAD_SUCCESS=true
    for module in "${BLOCKED_MODULES[@]}"; do
    	if ! grep -q "$module" /etc/modprobe.d/exclusions-rtl2832.conf; then
    		sudo -E "$(which bash)" -c "echo blacklist $module >>/etc/modprobe.d/exclusions-rtl2832.conf"
   	 	sudo -E "$(which bash)" -c "echo install $module /bin/false >>/etc/modprobe.d/exclusions-rtl2832.conf"
	    	sudo -E "$(which bash)" -c "modprobe -r $module 2>/dev/null" || UNLOAD_SUCCESS=false
	     fi
    done
    # Rebuild module dependency database factoring in blacklists
    if which depmod >/dev/null 2>&1; then
    	sudo depmod -a  >/dev/null 2>&1 || UNLOAD_SUCCESS=false
    else
    	UNLOAD_SUCCESS=false
    fi
    # On systems with initramfs, this needs to be updated to make sure the exclusions take effect:
    if which update-initramfs >/dev/null 2>&1; then
    	sudo update-initramfs -u  >/dev/null 2>&1 || true
    fi
    
    if [[ "${UNLOAD_SUCCESS}" == false ]]; then
	  echo "INFO: Although we've successfully excluded any competing RTL-SDR drivers, we weren't able to unload them. This will remedy itself when you reboot your system after the script finishes."
    fi
fi
echo "Making sure commands will persist when the terminal closes..."
sudo loginctl enable-linger "$(whoami)" >/dev/null 2>&1 || true
#
# The following prevents DHCPCD based systems from trying to assign IP addresses to each of the Docker containers.
# Note that this is not needed or available if the system uses DHCPD instead of DHCPCD.
if [[ -f /etc/dhcpcd.conf ]] && ! grep "denyinterfaces veth\*" /etc/dhcpcd.conf >/dev/null 2>&1
then
  echo -n "Excluding veth interfaces from dhcp. This will prevent problems if you are connected to the internet via WiFi when running many Docker containers... "
  sudo sh -c 'echo "denyinterfaces veth*" >> /etc/dhcpcd.conf'
  sudo systemctl is-enabled dhcpcd.service && sudo systemctl restart dhcpcd.service
  echo "done!"
fi

# Add some aliases to localhost in `/etc/hosts`. This will speed up recreation of images with docker-compose
if ! grep localunixsocket /etc/hosts >/dev/null 2>&1
then
  echo "Speeding up the recreation of containers when using docker-compose..."
  sudo sed -i 's/^\(127.0.0.1\s*localhost\)\(.*\)/\1\2 localunixsocket localunixsocket.local localunixsocket.home/g' /etc/hosts
fi

echo "Adding a crontab entry to ensure your system stays clean"
file="$(mktemp)"
crontab -l > "$file" || true
{ echo '#'
  echo '# Delete all unused containers (except those labeled do_not_prune) nightly at 3 AM'
  echo '# For example, docker-baseimage:rtlsdr is marked do_not_prune because it is used as a bash alias in rtl_test'
  echo '0 3 * * * /usr/bin/docker system prune -af --filter "label!=do_not_prune" >/dev/null 2>&1'
  echo '#'
  echo '# Delete all unused containers (incl those labeled do_not_prune) weekly at 3 AM'
  echo '0 4 * * 0 /usr/bin/docker system prune -af >/dev/null 2>&1' 
} >> "$file"
crontab - < "$file"
rm -f "$file"
cat << "EOM"
--------------------------------
We're done! Here are some final messages, read them carefully:
We've installed these packages, and we think they may be useful for you in the future. So we will leave them installed:
jq, git, rtl-sdr
If you don't want them, feel free to uninstall them using this command:
sudo apt-get remove jq git rtl-sdr

We have also installed chrony as NTP (time updating) client on your system. This has probably replaced any other NTP client you may have been using.
We're using chrony because this has proven to be the most stable way of keeping your system clock up to date, which is imperative for our containers to work properly.

--------------------------------
To make sure that everything works OK, you should reboot your machine.
Once rebooted, you are ready to go! For safety reasons, we won't do the reboot for you, but you can do it manually by typing:

sudo reboot

WARNING - if you are connected remotely to a Raspberry Pi (via SSH or VNC)
make sure you unplug any externally powered USB devices or hubs before rebooting
because these may cause your Raspberry Pi to get stuck in the \"off\" state!

--------------------------------
That is all -- thanks for using our docker-install script. You are now ready to create docker-compose.yml files and start running containers!
EOM

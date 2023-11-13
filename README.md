# docker-install

Script to help install Docker on Raspberry Pi and devices with similar Debian-based OSes

<img align="right" src="https://raw.githubusercontent.com/sdr-enthusiasts/sdr-enthusiast-assets/main/SDR%20Enthusiasts.svg" height="300">

- [docker-install](#docker-install)
  - [What is it?](#what-is-it)
  - [How to run it?](#how-to-run-it)
  - [Command Line Options](#command-line-options)
  - [Troubleshooting](#troubleshooting)
  - [Sample `docker-compose` configurations](#sample-docker-compose-configurations)
  - [Errors and how to deal with them](#errors-and-how-to-deal-with-them)
  - [License](#license)

## What is it?

The [docker-install.sh](docker-install.sh) script helps users get ready to use the [SDR-Enthusiasts](https://github.com/sdr-enthusiasts)' (@mikenye/@fredclausen/@k1xt) Docker containers.
The script is written to be used on a Debian (Ubuntu, DietPi, or Raspberry Pi OS) system that is "barebones", i.e., where Docker has not yet been installed. Debian OS versions Buster (Debian 10), Bullseye (Debian 11), and Bookworm (Debian 12) are supported. Debian OS Stretch (Debian 9) is no longer officially supported. The script should install successfully, but we are not providing any support for issues that occur on Debian Stretch.

Note that this script will work across a number of Debian-based Linux Operating Systems, but the SDR-Enthusiast container only work on these hardware architectures: `armhf` (32-bit ARM CPUs with hardware floating point processor), `arm64` (64-bit ARM CPUs with hardware floating point processor), and `amd64` (64-bit Intel CPUs).

We don't have sdr-enthusiasts containers available for any other architectures, including but not limited to `armel` (32-bit ARM CPUs with software floating point solution - some of the older Pi-Zero/Pi-1/Pi2 devices), `i386` (32 bits Intel CPUs), and `darwin` (MacOS devices).

It will **check**, and if necessary **install** the following components and settings:

- `docker`
  - install Docker
  - (optional) add the current user to the `sudoers` group and enable password-free use of `sudo`
  - configure log limits for Docker
  - configure $PATH environment for Docker
  - add current user to `docker` group
- `docker-compose`
  - Install latest stable `docker-compose` from Github (and not the older version from the Debian Repo)
- It will install a number of "helper" apps that are needed or recommended to use with the SDR-Enthusiasts containers
- On Stretch/Buster/Bullseye OS versions, it will make sure that `libseccomp2` is of a new enough version to support Bullseye-based Docker containers
- Update `udev` rules for use with RTL-SDR dongles
- Exclude and uninstall SDR drivers so the `SDR-Enthusiasts`' ADSB and ACARS containers can access the RTL-SDR dongles. Unload any preloaded drivers.
- on `dhcpd` based systems, exclude Docker Container-based virtual ethernet interfaces from using DHCP

After running this script, your system should be ready to use `docker` and `docker-compose`, and you can start adding a `docker-compose.yml` file as described in Mike Nye's ADSB Gitbook.

## How to run it?

- Feel free to inspect the script [here](docker-install.sh). You should really not blindly run other people's script - make sure you feel comfortable with what it does before executing it.
- The script assumes that `wget` is available, as it is on most systems. If it isn't, you may have to install it before running the script  with `sudo apt update && sudo apt install -y wget`
- To use it, you can enter the following command in your login session:

```bash
bash <(wget -q -O - https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
```

## Command Line Options

The script will install a number of packages, some of which are mandatory while others are optional. You can find the packages that will be installed [here](https://github.com/sdr-enthusiasts/docker-install/blob/main/docker-install.sh#L22).

If you want to exclude certain packages from being installed, you can do so by adding them to the command line with the prefix `no-`. For example to exclude `chrony` from being installed, you would use `no-chrony`.

In order to use command line options, it's easiest to download the script first, and then execute it from the command line like in this example:

```bash
wget -q https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh
chmod +x docker-install.sh
./docker-install.sh no-chrony
rm -f ./docker-install.sh
```

## Troubleshooting

This script is a work of love, and the authors don't provide support for alternative platforms or configurations.
Feel free to reuse those parts of the script that fit your purpose, subject to the License grant provided below.
If you need help or find a bug, please raise an Issue.
If you have improvements that you'd like to contribute, please raise a PR.

## Sample `docker-compose` configurations

This repository also includes 2 sample docker configuration files for use with `docker compose` that contain service definitions for most of the SDR-Enthusiasts containers. These files should not be used as-is, but are good examples that the user can copy and paste from when creating their own `docker-compose.yml`.
The sample configuration assumes that the `docker-compose.yml` file will be located in `/opt/adsb`. If you put your `docker-compose.yml` file in a different directory, you may have to update some of the volume mappings.

- [`docker-compose.yml`](sample-docker-compose.yml) sample
- [`.env`](sample-dot-env) sample

## Errors and how to deal with them

- ISSUE: The script fails with the message below:

```text
E: Repository 'http://raspbian.raspberrypi.org/raspbian buster InRelease' changed its 'Suite' value from 'stable' to 'oldstable'
E: Repository 'http://archive.raspberrypi.org/debian buster InRelease' changed its 'Suite' value from 'testing' to 'oldstable'
```

- SOLUTION: First run `sudo apt-get update --allow-releaseinfo-change && sudo apt-get upgrade -y` and then run the install script again.
- ISSUE: The "Hello World" docker test fails when executing the script.
- SOLUTION: Ignore this for now -- it will probably work once the system has been rebooted after completing the installation

## License

This software is licensed under the MIT License. The terms and conditions thereof can be found [here](LICENSE).

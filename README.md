<img align="right" src="https://raw.githubusercontent.com/sdr-enthusiasts/sdr-enthusiast-assets/main/SDR%20Enthusiasts.svg" height="300">

# docker-install

Script to help install Docker on Raspberry Pi and similar Debian-based OSes

## What is it?

The [docker-install.sh](docker-install.sh) script helps users get ready to use the SDR-Enthusiasts' (@mikenye/@fredclausen/@k1xt) Docker containers.
The script is written to be used on a Debian (Ubuntu, DietPi, or Raspberry Pi OS) system that is "barebones", i.e., where Docker has not yet been installed. Debian OS versions Stretch, Buster, Bullseye, and Bookworm are supported.

It will **check**, and if necessary **install** the following components and settings:

- `docker`
  - install Docker
  - (optional) add the current user to the `sudoers` group and enable password-free use of `sudo`
  - configure log limits for Docker
  - configure $PATH environment for Docker
  - add current user to `docker` group
- `docker-compose`
  - Install latest stable `docker-compose` from Github (and not the older version from the Debian Repo)
- Make sure that `libseccomp2` is of a new enough version to support Bullseye-based Docker containers
- Update `udev` rules for use with RTL-SDR dongles
- Exclude and uninstall SDR drivers so the `SDR-Enthusiasts`' ADSB and ACARS containers can access the RTL-SDR dongles. Unload any preloaded drivers.
- on `dhcpd` based systems, exclude Docker Container-based virtual ethernet interfaces from using DHCP

After running this script, your system should be ready to use `docker` and `docker-compose`, and you can start adding a `docker-compose.yml` file as described in Mike Nye's ADSB Gitbook.

## How to run it?

- Feel free to inspect the script [here](docker-install.sh). You should really not blindly run other people's script - make sure you feel comfortable with what it does before executing it.
- To use it, you can enter the following command in your login session:

```bash
bash <(curl -s https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
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
```
E: Repository 'http://raspbian.raspberrypi.org/raspbian buster InRelease' changed its 'Suite' value from 'stable' to 'oldstable'
E: Repository 'http://archive.raspberrypi.org/debian buster InRelease' changed its 'Suite' value from 'testing' to 'oldstable'
```
- SOLUTION: First run `sudo apt-get update --allow-releaseinfo-change && sudo apt-get upgrade -y` and then run the install script again.
- ISSUE: The "Hello World" docker test fails when executing the script.
- SOLUTION: Ignore this for now -- it will probably work once the system has been rebooted after completing the installation

## License
This software is licensed under the MIT License. The terms and conditions thereof can be found [here](LICENSE).

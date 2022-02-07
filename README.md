<img align="right" src="https://raw.githubusercontent.com/sdr-enthusiasts/sdr-enthusiast-assets/main/SDR%20Enthusiasts.svg" height="300">

# docker-install

Script to help install Docker on Raspberry Pi and similar Debian-based OSes
## What is it?
The [docker-install.sh](docker-install.sh) script helps users get ready to use the SDR-Enthusiasts' (@mikenye/@fredclausen/@k1xt) Docker containers.
The script is written to be used on a Debian (Ubuntu or Raspberry Pi OS) system that is "barebones", i.e., where Docker has not yet been installed. Debian OS versions Stretch, Buster, and Bullseye are supported.

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
- Blacklist SDR drivers so the `SDR-Enthusiasts`' ADSB and ACARS containers can access the RTL-SDR dongles. Unload any preloaded drivers.
- Ensure background commands (`nohup`) will stay active even after the login session terminates
- on `dhcpd` based systems, exclude Docker Container-based virtual ethernet interfaces from using DHCP

After running this script, your system should be ready to use `docker` and `docker-compose`, and you can start adding a `docker-compose.yml` file as described in Mike Nye's ADSB Gitbook.

## How to run it?
- Feel free to inspect the script [here](docker-install.sh). You should really not blindly run other people's script - make sure you feel comfortable with what it does before executing it.
- To use it, you can enter the following command in your login session:
```
source <(curl -s https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)
```

## Troubleshooting
This script is a work of love, and the authors don't provide support for alternative platforms or configurations.
Feel free to reuse those parts of the script that fit your purpose, subject to the License grant provided below.
If you need help or find a bug, please raise an Issue.
If you have improvements that you'd like to contribute, please raise a PR.

## License
This software is licensed under the MIT License. The terms and conditions thereof can be found [here](LICENSE).

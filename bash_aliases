alias ddown='docker compose down'
alias dir='ls -alsvh --color=auto'
alias dlogs='docker logs -n 100 -f'
alias docker-compose='docker compose'
alias dup='docker compose pull && docker compose up -d --remove-orphans && docker system prune -af --filter "label!=do_not_prune"'
alias nano='nano -l'
alias tb='nc termbin.com 9999'
alias usboff='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a off -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbon='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a on -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbstatus='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbtoggle='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a toggle -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'
alias dive="docker run -ti --rm  -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive"

export DOCKER_HOST="unix:///var/run/docker.sock"

function dexec () {
	# shortcut for "docker exec it container bash ..."
	[[ -z "$1" ]] && { echo "Usage: dexec <containername> [commands]"; return 99; } || true
	docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
        docker exec -it $1 bash ${@:2}
}

function dhealth () {
	# shows the HealthCheck status for a container
	[[ -z "$1" ]] && { echo "Usage: dhealth <container_name>"; return 99; } || true
	docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
        docker inspect --format "{{json .State.Health }}" $1 | jq '.Log[].Output'
}

function rtl_eeprom () {
        # this function is dockerized because the default Debian distro of rtl_sdr doesn't support some of the modern SDRs, e.g. RTLSDRv4
	docker run --label do_not_prune -it --device=/dev/bus/usb ghcr.io/sdr-enthusiasts/docker-baseimage:rtlsdr rtl_eeprom $@ |grep -v s6-rc
}

function rtl_test () {
        # this function is dockerized because the default Debian distro of rtl_sdr doesn't support some of the modern SDRs, e.g. RTLSDRv4
	docker run --label do_not_prune -it --device=/dev/bus/usb ghcr.io/sdr-enthusiasts/docker-baseimage:rtlsdr rtl_test $@ |grep -v s6-rc
}

function dip() {
    # this function shows the internal IP addresses and virtual ethernet interfaces that are created for each container
    docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
    readarray containers <<< "$(docker ps -q)"
    for c in ${containers[@]}; do
        veth="$(grep '^'"$(docker exec -it $c cat /sys/class/net/eth0/iflink | tr -d '\r')"'$' /sys/class/net/veth*/ifindex | awk -F'/' '{print $5}')"
                name="$(docker inspect --format '{{ .Name}}' $c)"
                ipaddress="$(docker inspect $c |sed -n 's|\s*"IPAddress": "\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\).*|\1|p' | tail -1)"
        if [[ -z "$1" ]] || [[ "${name//\//}" == "$1" ]]; then
                echo "${name//\//} ${ipaddress:-no_ipadress_found} ${veth:-no_interface_found}"
                if [[ -n "$1" ]]; then break; fi
        fi
    done
}

function transfer() {
        # from transfer.sh -- use this function to easily transfer and retrieves files in the cloud
        # file size is up to 10 Gb are stored for 14 days
        # The output of this function is a URL that can be used to retrieve the file with `wget` or `curl`
        if [ $# -eq 0 ]; then
                printf "No arguments specified.\nUsage:\nUploading files:   transfer <file|directory>\nDownloading files: transfer https://transfer.sh/filename [dest_filename]\n" >&2
                return 1
        fi
        file="$1"
        file_name=$(basename "$file")
        if [[ "${file:0:4}" == "http" ]]; then
                # transfer the file back to us
                if [[ -z "$2" ]]; then dest="$file_name"; else dest="$2"; fi
                if [[ -e "$dest" ]]; then
                       printf "Error - destination file \"%s\" already exists. Please remove that file first, or use \"transfer https://transfer.sh/filename new_filename\"\n" "$dest"
                       return 1
                fi
                curl --progress-bar "$file" > "$dest"
                if [[ "${dest##*.}" == "tgz" ]]; then
                        echo "You can unpack this file tree with \"tar xvf $dest\" or \"tar xvf $dest -C /target/directory\""
                fi
                return 0
        fi
        if [ ! -e "$file" ]; then
                echo "$file: No such file or directory" >&2
                return 1
        fi
        if [ -d "$file" ]; then
                file_name="$file_name.tgz"
                tempfile=$(mktemp --suffix=.tgz)
                echo -n "Compressing directory $file... "
                tar zcf "$tempfile" "$file"
                echo "Uploading to transfer.sh..."
                curl --progress-bar --upload-file "$tempfile" "https://transfer.sh/$file_name"
                rm -f "$tempfile"
        else
                curl --progress-bar --upload-file "$file" "https://transfer.sh/$file_name"
        fi
        echo
}

function dupall() { for d in /opt/*; do if [[ -f "$d/docker-compose.yml" ]]; then pushd "$d"; dup; popd; fi; done; }

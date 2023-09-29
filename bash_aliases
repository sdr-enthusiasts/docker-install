alias ddown='docker compose down'
alias dir='ls -alsvh --color=auto'
alias dlogs='docker logs -n 100 -f'
alias docker-compose='docker compose'
alias dup='docker compose pull && docker compose up -d --remove-orphans && docker system prune -af'
alias nano='nano -l'
alias tb='nc termbin.com 9999'
alias usboff='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a off -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbon='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a on -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbstatus='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl || echo "Sorry, this is only available on Raspberry Pi 4"'
alias usbtoggle='grep "Raspberry Pi 4" /sys/firmware/devicetree/base/model >/dev/null 2>&1 && sudo uhubctl -a toggle -l 1-1 || echo "Sorry, this is only available on Raspberry Pi 4"'

export DOCKER_HOST="unix:///var/run/docker.sock"

function dexec () {
	# shortcut for "docker exec it container bash ..."
	[[ -n "$1" ]] && { echo "Usage: dexec <containername> [commands]"; return 99; }
	docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
        docker exec -it $1 bash ${@:2}
}

function dhealth () {
	# shows the HealthCheck status for a container
	[[ -n "$1" ]] && { echo "Usage: dhealth <container_name>"; return 99; }
	docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
        docker inspect --format "{{json .State.Health }}" $1 | jq '.Log[].Output'
}

function rtl_eeprom () {
        # this function is dockerized because the default Debian distro of rtl_sdr doesn't support some of the modern SDRs, e.g. RTLSDRv4
	docker run  --rm -it --device=/dev/bus/usb ghcr.io/sdr-enthusiasts/docker-baseimage:rtlsdr rtl_eeprom $@ |grep -v s6-rc
}

function rtl_test () {
        # this function is dockerized because the default Debian distro of rtl_sdr doesn't support some of the modern SDRs, e.g. RTLSDRv4
	docker run  --rm -it --device=/dev/bus/usb ghcr.io/sdr-enthusiasts/docker-baseimage:rtlsdr rtl_test $@ |grep -v s6-rc
}

function dip() {
    # this function shows the internal IP addresses and virtual ethernet interfaces that are created for each container
    docker ps | grep "Up" >/dev/null 2>&1 || { echo "No containers are running."; return 1; }
    readarray containers <<< "$(docker ps -q)"
    for c in ${containers[@]}; do
        veth="$(grep '^'"$(docker exec -it $c cat /sys/class/net/eth0/iflink | tr -d '\r')"'$' /sys/class/net/veth*/ifindex | awk -F'/' '{print $5}')"
                name="$(docker inspect --format '{{ .Name}}' $c)"
                ipaddress="$(grep -v "no value" <<< "$(docker inspect --format '{{ .NetworkSettings.Networks.'"$(docker inspect --format '{{ .HostConfig.NetworkMode }}' $c)"'.IPAddress }}' $c 2>/dev/null | sed 's/ \// /')")"
        echo "${name//\//} ${ipaddress:-no_ipadress_found} ${veth:-no_interface_found}"
    done
} 

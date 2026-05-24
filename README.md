# Dincus Project

## Pull start script

```
curl -o start.sh -sSL "https://raw.githubusercontent.com/manprint/dincus/main/start.sh" && \
chmod +x start.sh
```

or

```
wget "https://raw.githubusercontent.com/manprint/dincus/main/start.sh" && \
chmod +x start.sh
```

## Pull Compose

Per scaricare `compose.yml` nella directory corrente e creare subito le cartelle
dei mount point:

```bash
curl -fsSL "https://raw.githubusercontent.com/manprint/dincus/main/setup.sh" | bash
```

## Docker Compose

Il file `compose.yaml` replica l'avvio definito in `start.sh`: stessa immagine,
stesse porte, stessa rete bridge dedicata con IP statico e gli stessi volumi
`local` con `driver_opts` bind verso `./data`, in modo da preservare il
popolamento iniziale delle directory del container al primo avvio. In piu
persiste anche `/var/lib/containerd`, che serve quando Docker usa il
containerd image store con snapshotter `overlayfs`.

```bash
mkdir -vp ./data/{home,root,docker,containerd,incus}
docker compose up -d
```

Per fermare e rimuovere container e rete:

```bash
docker compose down
```

Per replicare anche la rimozione dei volumi fatta da `start.sh down`:

```bash
docker compose down -v
```

## Extended Start Script

```
#!/bin/bash

VT="type=volume"
VNAME="source"
VDST="dst"
VOLUME_OPT="volume-driver=local,volume-opt=type=none,volume-opt=o=bind"
VLOC="volume-opt=device"

DIND_BRIDGE_NAME="dincus_br"
SUBNET="10.10.155.0/30"
GATEWAY="10.10.155.2"

IMAGE="ghcr.io/manprint/dincus:1.0.16"
CONTAINER="dincus"
CONTAINER_IP="10.10.155.1"

# Definizione delle funzioni
#----------------------------------------
#----------------------------------------

function __mkdir() {
    mkdir -vp $(pwd)/data/{home,root,docker,containerd,incus}
}

function __create_network() {
    docker network create \
        --opt com.docker.network.bridge.name=${DIND_BRIDGE_NAME} \
        --driver=bridge \
        --subnet=${SUBNET} \
        --gateway=${GATEWAY} \
        ${CONTAINER}_net
}

function down() {
    docker stop ${CONTAINER}
    docker rm ${CONTAINER}
    docker volume rm --force ${CONTAINER}_home_vol ${CONTAINER}_root_vol ${CONTAINER}_docker_vol ${CONTAINER}_containerd_vol ${CONTAINER}_incus_vol
    docker network rm ${CONTAINER}_net
}

function up() {
    down
    __mkdir
    __create_network
    docker run -dit \
        --privileged \
        -p 2244:22 \
        -p 2388:2375 \
        --name=${CONTAINER} \
        --hostname="${CONTAINER}.noc" \
        --network=${CONTAINER}_net \
        --ip=${CONTAINER_IP} \
        --restart=always \
        --cgroupns=host \
        --tmpfs /tmp --tmpfs /run --tmpfs /run/lock --tmpfs /var/run \
        -v /sys/fs/cgroup:/sys/fs/cgroup -v /dev:/dev -v /lib/modules:/lib/modules:ro \
        --mount "$VT,$VNAME=${CONTAINER}_home_vol,$VDST=/home,$VOLUME_OPT,$VLOC=$(pwd)/data/home" \
        --mount "$VT,$VNAME=${CONTAINER}_root_vol,$VDST=/root,$VOLUME_OPT,$VLOC=$(pwd)/data/root" \
        --mount "$VT,$VNAME=${CONTAINER}_docker_vol,$VDST=/var/lib/docker,$VOLUME_OPT,$VLOC=$(pwd)/data/docker" \
        --mount "$VT,$VNAME=${CONTAINER}_containerd_vol,$VDST=/var/lib/containerd,$VOLUME_OPT,$VLOC=$(pwd)/data/containerd" \
        --mount "$VT,$VNAME=${CONTAINER}_incus_vol,$VDST=/var/lib/incus,$VOLUME_OPT,$VLOC=$(pwd)/data/incus" \
        -e DOCKER_BIP="--bip=10.5.10.1/24" \
        -e DOCKER_TCP_PORT="-H=tcp://0.0.0.0:2375" \
        -e DOCKER_STORAGE_TYPE="overlay2" \
        -e PROMPT_TAG="dincus-cont" \
        ${IMAGE}
}

#----------------------------------------
#----------------------------------------
# Nota: Non modificare il codice seguente

print_function_list() {
    declare -F | awk '{print $3}' | grep -v "^print_function_list$\|^error_handler$\|^__"
}

if [ $# -gt 0 ]; then
    function_name="$1"
    shift
    if declare -F "$function_name" >/dev/null; then
        "$function_name" "$@"
    else
        echo "Funzione non trovata: $function_name"
        exit 1
    fi
else
    echo
    echo -e "Le seguenti funzioni sono definite nello script \e[32m$0\e[0m"
    echo "Per eseguirle, lancia i comandi come specificato sotto:"
    echo
    for function_name in $(print_function_list); do
        echo -e "  \e[32m$0\e[0m \e[31m$function_name\e[0m"
    done
    echo
fi
```
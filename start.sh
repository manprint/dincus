#!/bin/bash

BRIDGE_NAME="dincus_br"
SUBNET="10.10.155.0/30"
GATEWAY="10.10.155.2"

IMAGE="ghcr.io/manprint/dincus:1.0.0"
CONTAINER="dincus"
CONTAINER_IP="10.10.155.1"

# Definizione delle funzioni
#----------------------------------------
#----------------------------------------

function __mkdir() {
    mkdir -vp $(pwd)/data/{debian,root,incus,docker}
}

function __create_network() {
    docker network create \
        --opt com.docker.network.bridge.name=${BRIDGE_NAME} \
        --driver=bridge \
        --subnet=${SUBNET} \
        --gateway=${GATEWAY} \
        ${CONTAINER}_net
}

function down() {
    docker stop ${CONTAINER}
    docker rm ${CONTAINER}
    docker network rm ${CONTAINER}_net
}

function up() {
    down
    __mkdir
    __create_network
    docker run -dit \
        --privileged \
        -p 2244:22 \
        --name=${CONTAINER} \
        --hostname="${CONTAINER}.noc" \
        --network=${CONTAINER}_net \
        --ip=${CONTAINER_IP} \
        --restart=always \
        --cgroupns=host \
        --pid=host \
        -v /etc/localtime:/etc/localtime:ro \
        -v /lib/modules:/lib/modules:ro \
        -v $(pwd)/data/incus:/var/lib/incus \
        -v $(pwd)/data/docker:/var/lib/docker \
        -v $(pwd)/data/root:/root \
        -v $(pwd)/data/debian:/home/debian \
        -e SETIPTABLES=true \
        -e DEFAULT_USER=debian \
        -e BIP_ADDRESS="${BIP_ADDRESS:-10.20.30.1/24}" \
        -e ENVIRONMENT="${ENVIRONMENT:-dincus-dev}" \
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

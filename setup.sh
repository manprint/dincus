#!/bin/bash

set -euo pipefail

COMPOSE_URL="${COMPOSE_URL:-https://raw.githubusercontent.com/manprint/dincus/main/compose.yaml}"

download_compose() {
    if [[ "$COMPOSE_URL" == file://* ]]; then
        cp "${COMPOSE_URL#file://}" compose.yml
        return
    fi

    if [[ -f "$COMPOSE_URL" ]]; then
        cp "$COMPOSE_URL" compose.yml
        return
    fi

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL -o compose.yml "$COMPOSE_URL"
        return
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO compose.yml "$COMPOSE_URL"
        return
    fi

    echo "Errore: serve curl oppure wget per scaricare compose.yml" >&2
    exit 1
}

create_mount_dirs() {
    mkdir -vp "$(pwd)"/data/{home,root,docker,containerd,incus}
}

download_compose
create_mount_dirs
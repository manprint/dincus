set positional-arguments := true
set dotenv-load := true
set shell := ["bash", "-c"]

# List all tasks
_default:
    @just --list

# Docker login
login:
    #!/usr/bin/env bash
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD

# Docker build
push: login
    #!/usr/bin/env bash
    date=$(date +%Y%m%d)
    docker builder rm mybuilder || true
    docker builder create --name mybuilder --use
    docker buildx build --platform linux/amd64,linux/arm64 -t fabiop85/dincus:latest -t fabiop85/dincus:1.0.7 --push .
    docker builder rm mybuilder || true

# Test AMD64 and ARM64 buildx
test_buildx:
    #!/usr/bin/env bash
    date=$(date +%Y%m%d)
    docker builder rm mybuilder || true
    docker builder create --name mybuilder --use
    docker buildx build --platform linux/amd64,linux/arm64 -t fabiop85/dincus:test .
    docker builder rm mybuilder || true

# Docker build local for test
build_local_amd64:
    #!/usr/bin/env bash
    date=$(date +%Y%m%d)
    docker build -t fabiop85/dincus:amd64-test .
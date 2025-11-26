#!/bin/bash

set -e
mkdir -p /etc/docker
: > /etc/docker/env
[ -n "$DOCKER_BIP" ] && echo "DOCKER_BIP=$DOCKER_BIP" >> /etc/docker/env
[ -n "$DOCKER_TCP_PORT" ] && echo "DOCKER_TCP_PORT=$DOCKER_TCP_PORT" >> /etc/docker/env
[ -n "$DOCKER_STORAGE_TYPE" ] && echo "DOCKER_STORAGE_TYPE=$DOCKER_STORAGE_TYPE" >> /etc/docker/env
if [ -n "$PROMPT_TAG" ]; then
	echo "export PROMPT_TAG=\"$PROMPT_TAG\"" > /etc/profile.d/prompt_tag.sh
	chmod 644 /etc/profile.d/prompt_tag.sh
fi
exec /lib/systemd/systemd

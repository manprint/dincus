FROM debian:trixie AS builder

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends systemd systemd-sysv adduser sudo net-tools tmux byobu locales tree procps \
        curl wget nano iputils-ping apt-transport-https ca-certificates gnupg lsb-release tzdata coreutils util-linux \
        fuse3 libfuse2 fuse-overlayfs cron git screen iproute2 iptables-persistent \
        gnupg2 htop apt-utils rsync jq zip unzip pixz host make openssl sshpass xz-utils \
        pigz zstd isal autossh mbuffer telnet nmap dnsutils gpg \
        libsystemd0 dbus kmod dnsmasq udev fuse nftables ebtables arptables \
        iptables kmod lsof isal \
    && sed -i '/it_IT.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen it_IT.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN cd /lib/systemd/system/sysinit.target.wants/ \
    && rm $(ls | grep -v systemd-tmpfiles-setup)

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/basic.target.wants/* \
    /lib/systemd/system/anaconda.target.wants/* \
    /lib/systemd/system/plymouth* \
    /lib/systemd/system/systemd-update-utmp*

RUN systemctl mask systemd-udevd.service \
        systemd-udevd-kernel.socket \
        systemd-udevd-control.socket \
        systemd-modules-load.service \
        sys-kernel-debug.mount \
        sys-kernel-tracing.mount \
        sys-kernel-config.mount \
        e2scrub_reap.service \
        e2scrub_all.timer

RUN mkdir -p /etc/apt/keyrings/ && \
    curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc && \
    cat > /etc/apt/sources.list.d/zabbly-incus-stable.sources <<EOF
Enabled: yes
Types: deb
URIs: https://pkgs.zabbly.com/incus/stable
Suites: trixie
Components: main
Architectures: ${TARGETARCH}
Signed-By: /etc/apt/keyrings/zabbly.asc
EOF

RUN apt-get update && apt-get install -y incus incus-ui-canonical && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1000 debian
RUN useradd -m -s /bin/bash -u 1000 debian -g debian && \
    echo "debian:debian" | chpasswd && \
    echo "root:root" | chpasswd && \
    adduser debian sudo

RUN echo "debian ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

RUN curl --proto '=https' --tlsv1.2 -fsSL https://get.opentofu.org/install-opentofu.sh -o install-opentofu.sh && \
    chmod +x install-opentofu.sh && \
    ./install-opentofu.sh --install-method deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm install-opentofu.sh

RUN echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf

RUN apt-get update \
    && curl -fsSL https://get.docker.com -o get-docker.sh \
    && sh get-docker.sh \
    && rm get-docker.sh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp

RUN apt-get update && apt-get install --no-install-recommends -y openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir /home/debian/.ssh \
    && chown debian:debian /home/debian/.ssh \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

COPY docker.service /usr/lib/systemd/system/docker.service
COPY sshd_config /etc/ssh/sshd_config
ADD --chown=debian:debian https://gitea.adiprint.it/fabio/public-utils-scripts/raw/branch/master/.bashrc-template /home/debian/.bashrc
ADD --chown=root:root https://gitea.adiprint.it/fabio/public-utils-scripts/raw/branch/master/.bashrc-template /root/.bashrc
RUN sed -i '/PROMPT_TAG=/i if [ -f /etc/profile.d/prompt_tag.sh ]; then source /etc/profile.d/prompt_tag.sh; fi' /home/debian/.bashrc
RUN sed -i '/PROMPT_TAG=/i if [ -f /etc/profile.d/prompt_tag.sh ]; then source /etc/profile.d/prompt_tag.sh; fi' /root/.bashrc
RUN sudo usermod -aG docker debian && systemctl enable docker && systemctl enable ssh && systemctl enable cron
ADD https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker /etc/bash_completion.d/docker.sh

RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin

RUN curl -sfL https://direnv.net/install.sh | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/local/sbin/direnv /usr/local/bin/direnv

RUN apt update && curl https://rclone.org/install.sh | bash && \
    rclone completion bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
RUN echo "user_allow_other" >> /etc/fuse.conf

RUN echo '\nexport PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games' >> /home/debian/.bashrc
RUN echo '\nexport PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games' >> /root/.bashrc

RUN ln -fs /usr/share/zoneinfo/Europe/Rome /etc/localtime && dpkg-reconfigure -f noninteractive tzdata

ENV LANG=it_IT.UTF-8 \
    LANGUAGE=it_IT:it \
    LC_ALL=it_IT.UTF-8 \
    TZ=Europe/Rome

RUN usermod -aG incus-admin debian

# Setups for Incus services
RUN mkdir -vp /root/.incus-env
COPY ./incus-services/incus-lxcfs.service /etc/systemd/system/incus-lxcfs.service
COPY ./incus-services/incus.service /etc/systemd/system/incus.service
COPY ./incus-services/incus /root/.incus-env/incus
RUN mkdir -vp /var/log/incus && touch /var/log/incus/incus.log

# Enable Incus services
RUN systemctl enable incus-lxcfs
RUN systemctl enable incus

RUN mkdir -vp /home/debian/.supercronic
RUN chown debian:debian /home/debian/.supercronic
RUN mkdir -vp /root/.supercronic
COPY ./supercronic/cron /home/debian/.supercronic/cron
COPY ./supercronic/cron /root/.supercronic/cron
RUN chown debian:debian /home/debian/.supercronic/cron

RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -O /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-amd64; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -O /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-arm64; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi
RUN chmod +x /usr/local/bin/supercronic

COPY ./supercronic/supercronic-debian.service /etc/systemd/system/supercronic-debian.service
COPY ./supercronic/supercronic-root.service /etc/systemd/system/supercronic-root.service

RUN systemctl enable supercronic-debian.service
RUN systemctl enable supercronic-root.service

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN apt-get clean && rm -rf /var/lib/apt/lists/

FROM scratch AS final

COPY --from=builder / /

VOLUME [ "/sys/fs/cgroup" ]

EXPOSE 2375 22

STOPSIGNAL SIGRTMIN+3

CMD ["/usr/local/bin/docker-entrypoint.sh"]
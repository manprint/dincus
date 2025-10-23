FROM debian:bookworm-slim

# We make a fake systemctl so that incus doesn't error out without systemd
RUN echo "#!/bin/bash" > /sbin/systemctl && \
    echo "exit 0" >> /sbin/systemctl && \
    chmod +x /sbin/systemctl && \
    echo "deb http://deb.debian.org/debian bookworm contrib" >> /etc/apt/sources.list && \
# Install curl so we can install the keyring.
    apt-get update && \
    apt-get install --no-install-recommends -y curl ca-certificates && \
# Ensure skeleton files are present
    apt-get install --no-install-recommends -y bash-completion && \
    mkdir -p /etc/skel && \
    [ -f /etc/skel/.bashrc ] || cp /usr/share/base-files/dot.bashrc /etc/skel/.bashrc 2>/dev/null || echo 'export PS1="\u@\h:\w\$ "' > /etc/skel/.bashrc && \
    [ -f /etc/skel/.profile ] || cp /usr/share/base-files/dot.profile /etc/skel/.profile 2>/dev/null || echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' > /etc/skel/.profile && \
    [ -f /etc/skel/.bash_logout ] || touch /etc/skel/.bash_logout && \
# Enable colors and add aliases in bashrc
    echo '' >> /etc/skel/.bashrc && \
    echo '# Force color prompt' >> /etc/skel/.bashrc && \
    echo 'force_color_prompt=yes' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Enable colors' >> /etc/skel/.bashrc && \
    echo 'export LS_OPTIONS="--color=auto"' >> /etc/skel/.bashrc && \
    echo 'eval "$(dircolors)"' >> /etc/skel/.bashrc && \
    echo 'alias ls="ls $LS_OPTIONS"' >> /etc/skel/.bashrc && \
    echo 'alias ll="ls -alFh"' >> /etc/skel/.bashrc && \
    echo 'alias l="ls -CF"' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Colored GCC warnings and errors' >> /etc/skel/.bashrc && \
    echo 'export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Colored prompt' >> /etc/skel/.bashrc && \
    echo 'PS1="\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;31m\](${ENVIRONMENT:-dev})\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Set complete PATH with all binary directories' >> /etc/skel/.bashrc && \
    echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/incus/bin"' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Enable bash completion for just' >> /etc/skel/.bashrc && \
    echo '[ -f /etc/bash_completion.d/just ] && . /etc/bash_completion.d/just' >> /etc/skel/.bashrc && \
    echo '' >> /etc/skel/.bashrc && \
    echo '# Enable direnv hook' >> /etc/skel/.bashrc && \
    echo 'eval "$(direnv hook bash)"' >> /etc/skel/.bashrc && \
    mkdir -p /etc/apt/keyrings/ && \
    curl -fsSL https://pkgs.zabbly.com/key.asc -o /etc/apt/keyrings/zabbly.asc && \
    echo "deb [signed-by=/etc/apt/keyrings/zabbly.asc] https://pkgs.zabbly.com/incus/stable $(. /etc/os-release && echo ${VERSION_CODENAME}) main" > /etc/apt/sources.list.d/zabbly-incus-stable.list && \
# Install incus and so on
    apt-get update && \
    apt-get install --no-install-recommends -y fuse3 nftables ebtables arptables iproute2 thin-provisioning-tools openvswitch-switch btrfs-progs lvm2 udev iptables kmod unzip zip zstd wget && \
    apt-get install --no-install-recommends --no-install-suggests -y zfsutils-linux sshpass screen tmux byobu && \
    apt-get install --no-install-recommends -y incus && \
    curl https://rclone.org/install.sh | bash && \
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        wget -O /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-amd64; \
    elif [ "$ARCH" = "aarch64" ]; then \
        wget -O /usr/local/bin/supercronic https://github.com/aptible/supercronic/releases/latest/download/supercronic-linux-arm64; \
    else \
        echo "Unsupported architecture: $ARCH"; exit 1; \
    fi && \
    chmod +x /usr/local/bin/supercronic && \
# Install Docker
    apt-get install --no-install-recommends -y apt-transport-https gnupg2 software-properties-common && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install --no-install-recommends -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
# Install useful utilities
    apt-get install --no-install-recommends -y wget nano vim net-tools iputils-ping telnet dnsutils procps htop less tree git openssh-server cron sudo make && \
# Install just (command runner)
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to /usr/local/bin && \
    mkdir -p /etc/bash_completion.d && \
    just --completions bash > /etc/bash_completion.d/just && \
    docker completion bash > /etc/bash_completion.d/docker && \
    rclone completion bash > /etc/bash_completion.d/rclone && \
    incus completion bash > /etc/bash_completion.d/incus && \
# Install direnv
    curl -sfL https://direnv.net/install.sh | bash && \
# Create debian user with UID/GID 1000
    groupadd -g 1000 debian && \
    useradd -m -u 1000 -g 1000 -s /bin/bash debian && \
    usermod -aG docker debian && \
    usermod -aG incus-admin debian && \
    usermod -aG sudo debian && \
    echo "debian ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
# Supercronic setup (cartelle, file, permessi)
    mkdir -vp /home/debian/.supercronic && \
    mkdir -vp /root/.supercronic && \
    chown -R debian:debian /home/debian/.supercronic && \
    chown -R root:root /root/.supercronic && \
# Set passwords for root and debian
    echo "root:root" | chpasswd && \
    echo "debian:debian" | chpasswd && \
# Configure SSH
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    apt autoremove -y && \
    apt-get clean && \
#    update-alternatives --set iptables /usr/sbin/iptables-legacy && \
#    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy && \
#    update-alternatives --set arptables /usr/sbin/arptables-legacy && \
#    update-alternatives --set ebtables /usr/sbin/ebtables-legacy && \
    echo '#!/bin/bash' > /start.sh && \
    # Ensure supercronic directories and cron files exist at runtime
    echo 'if [ ! -d /home/debian/.supercronic ]; then' >> /start.sh && \
    echo '  mkdir -p /home/debian/.supercronic' >> /start.sh && \
    echo '  chown debian:debian /home/debian/.supercronic' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ ! -f /home/debian/.supercronic/cron ]; then' >> /start.sh && \
    echo '  echo -e "SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/incus/bin" > /home/debian/.supercronic/cron' >> /start.sh && \
    echo '  chown debian:debian /home/debian/.supercronic/cron' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ ! -d /root/.supercronic ]; then' >> /start.sh && \
    echo '  mkdir -p /root/.supercronic' >> /start.sh && \
    echo '  chown root:root /root/.supercronic' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'if [ ! -f /root/.supercronic/cron ]; then' >> /start.sh && \
    echo '  echo -e "SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/incus/bin" > /root/.supercronic/cron' >> /start.sh && \
    echo '  chown root:root /root/.supercronic/cron' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Export ENVIRONMENT globally for all shells (PRIMA DI TUTTO)' >> /start.sh && \
    echo 'if [ -n "$ENVIRONMENT" ]; then' >> /start.sh && \
    echo '  echo "export ENVIRONMENT=\"$ENVIRONMENT\"" > /etc/profile.d/environment.sh' >> /start.sh && \
    echo '  chmod 644 /etc/profile.d/environment.sh' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "export ENVIRONMENT=\"dev\"" > /etc/profile.d/environment.sh' >> /start.sh && \
    echo '  chmod 644 /etc/profile.d/environment.sh' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'trap "cleanup; exit" SIGTERM' >> /start.sh && \
    echo '# Copy skeleton files to /root if they do not exist' >> /start.sh && \
    echo 'if [ ! -f /root/.bashrc ]; then' >> /start.sh && \
    echo '  echo "Copying skeleton files to /root..."' >> /start.sh && \
    echo '  cp -n /etc/skel/.* /root/ 2>/dev/null || true' >> /start.sh && \
    echo '  echo "Skeleton files copied."' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "Skeleton files already exist in /root, skipping copy."' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Copy skeleton files to /home/debian if they do not exist' >> /start.sh && \
    echo 'if [ ! -f /home/debian/.bashrc ]; then' >> /start.sh && \
    echo '  echo "Copying skeleton files to /home/debian..."' >> /start.sh && \
    echo '  cp -n /etc/skel/.* /home/debian/ 2>/dev/null || true' >> /start.sh && \
    echo '  chown -R 1000:1000 /home/debian' >> /start.sh && \
    echo '  echo "Skeleton files copied to /home/debian."' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "Skeleton files already exist in /home/debian, skipping copy."' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'cleanup() {' >> /start.sh && \
    echo '  echo "Stopping cron..."' >> /start.sh && \
    echo '  pkill -TERM cron' >> /start.sh && \
    echo '  echo "Stopped cron."' >> /start.sh && \
    echo '  echo "Stopping SSH..."' >> /start.sh && \
    echo '  pkill -TERM sshd' >> /start.sh && \
    echo '  echo "Stopped SSH."' >> /start.sh && \
    echo '  echo "Stopping Docker..."' >> /start.sh && \
    echo '  pkill -TERM dockerd' >> /start.sh && \
    echo '  pkill -TERM containerd' >> /start.sh && \
    echo '  echo "Stopped Docker."' >> /start.sh && \
    echo '  echo "Stopping incusd..."' >> /start.sh && \
    echo '  incus admin shutdown' >> /start.sh && \
    echo '  pkill -TERM incusd' >> /start.sh && \
    echo '  echo "Stopped incusd."' >> /start.sh && \
    echo '  echo "Stopping lxcfs..."' >> /start.sh && \
    echo '  pkill -TERM lxcfs' >> /start.sh && \
    echo '  fusermount -u /var/lib/incus-lxcfs' >> /start.sh && \
    echo '  echo "Stopped lxcfs."' >> /start.sh && \
    echo ' CHILD_PIDS=$(pgrep -P $$)' >> /start.sh && \
    echo ' if [ -n "$CHILD_PIDS" ]; then' >> /start.sh && \
    echo '   pkill -TERM -P $$' >> /start.sh && \
    echo '   echo "Stopped child processes with PIDs: $CHILD_PIDS"' >> /start.sh && \
    echo ' else' >> /start.sh && \
    echo '   echo "No child processes found."' >> /start.sh && \
    echo ' fi' >> /start.sh && \
    echo '}' >> /start.sh && \
    echo 'export PATH="/opt/incus/bin/:${PATH}"' >> /start.sh && \
    echo 'export INCUS_EDK2_PATH="/opt/incus/share/qemu/"' >> /start.sh && \
    echo 'export LD_LIBRARY_PATH="/opt/incus/lib/"' >> /start.sh && \
    echo 'export INCUS_LXC_TEMPLATE_CONFIG="/opt/incus/share/lxc/config/"' >> /start.sh && \
    echo 'export INCUS_DOCUMENTATION="/opt/incus/doc/"' >> /start.sh && \
    echo 'export INCUS_LXC_HOOK="/opt/incus/share/lxc/hooks/"' >> /start.sh && \
    echo 'export INCUS_AGENT_PATH="/opt/incus/agent/"' >> /start.sh && \
    echo 'if [ "$SETIPTABLES" = "true" ]; then' >> /start.sh && \
    echo '  if ! iptables-legacy -C DOCKER-USER -j ACCEPT &>/dev/null; then' >> /start.sh && \
    echo '    iptables-legacy -I DOCKER-USER -j ACCEPT' >> /start.sh && \
    echo '  fi' >> /start.sh && \
    echo '  if ! ip6tables-legacy -C DOCKER-USER -j ACCEPT &>/dev/null; then' >> /start.sh && \
    echo '    ip6tables-legacy -I DOCKER-USER -j ACCEPT' >> /start.sh && \
    echo '  fi' >> /start.sh && \
    echo '  if ! iptables -C DOCKER-USER -j ACCEPT &>/dev/null; then' >> /start.sh && \
    echo '    iptables -I DOCKER-USER -j ACCEPT' >> /start.sh && \
    echo '  fi' >> /start.sh && \
    echo '  if ! ip6tables -C DOCKER-USER -j ACCEPT &>/dev/null; then' >> /start.sh && \
    echo '    ip6tables -I DOCKER-USER -j ACCEPT' >> /start.sh && \
    echo '  fi' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Clean up stale PIDs on restart' >> /start.sh && \
    echo 'echo "Cleaning up stale PIDs..."' >> /start.sh && \
    echo 'rm -vf /var/run/docker.pid /run/docker.pid' >> /start.sh && \
    echo 'rm -vf /var/run/containerd/containerd.pid /run/containerd/containerd.pid' >> /start.sh && \
    echo 'rm -vf /var/run/docker.sock /run/docker.sock' >> /start.sh && \
    echo 'rm -vf /var/run/crond.pid /run/crond.pid /var/run/cron.pid /run/cron.pid' >> /start.sh && \
    echo 'echo "PIDs cleaned up."' >> /start.sh && \
    echo '# Start containerd' >> /start.sh && \
    echo 'echo "Starting containerd..."' >> /start.sh && \
    echo 'containerd &' >> /start.sh && \
    echo 'CONTAINERD_PID=$!' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '# Start Docker daemon' >> /start.sh && \
    echo 'echo "Starting Docker daemon..."' >> /start.sh && \
    echo '# Configure Docker bridge IP if BIP_ADDRESS is set' >> /start.sh && \
    echo 'DOCKERD_OPTS="-H unix:///var/run/docker.sock -H tcp://0.0.0.0:2375"' >> /start.sh && \
    echo 'if [ -n "$BIP_ADDRESS" ]; then' >> /start.sh && \
    echo '  echo "Configuring Docker bridge with IP: $BIP_ADDRESS"' >> /start.sh && \
    echo '  dockerd $DOCKERD_OPTS --bip="$BIP_ADDRESS" &' >> /start.sh && \
    echo 'else' >> /start.sh && \
    echo '  echo "Using default Docker bridge configuration"' >> /start.sh && \
    echo '  dockerd $DOCKERD_OPTS &' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo 'DOCKERD_PID=$!' >> /start.sh && \
    echo 'sleep 3' >> /start.sh && \
    echo 'echo "Docker started."' >> /start.sh && \
    echo '  mkdir -p /var/lib/incus-lxcfs' >> /start.sh && \
    echo '  /opt/incus/bin/lxcfs /var/lib/incus-lxcfs --enable-loadavg --enable-cfs &' >> /start.sh && \
    echo '/usr/lib/systemd/systemd-udevd &' >> /start.sh && \
    echo 'UDEVD_PID=$!' >> /start.sh && \
    echo '/opt/incus/bin/incusd &' >> /start.sh && \
    echo 'sleep 2' >> /start.sh && \
    echo '# Fix Incus socket permissions for debian user' >> /start.sh && \
    echo 'if [ -S /var/lib/incus/unix.socket ]; then' >> /start.sh && \
    echo '  chgrp incus-admin /var/lib/incus/unix.socket' >> /start.sh && \
    echo '  chmod g+rw /var/lib/incus/unix.socket' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Start SSH' >> /start.sh && \
    echo 'echo "Starting SSH server..."' >> /start.sh && \
    echo '/usr/sbin/sshd' >> /start.sh && \
    echo 'echo "SSH started."' >> /start.sh && \
    echo '# Start cron' >> /start.sh && \
    echo 'echo "Starting cron..."' >> /start.sh && \
    echo '/usr/sbin/cron' >> /start.sh && \
    echo 'echo "Cron started."' >> /start.sh && \
    echo '# Start supercronic for debian and root' >> /start.sh && \
    echo 'touch /var/log/supercronic-debian.log && chmod 664 /var/log/supercronic-debian.log' >> /start.sh && \
    echo 'chown debian:debian /var/log/supercronic-debian.log' >> /start.sh && \
    echo 'sudo -u debian /usr/local/bin/supercronic /home/debian/.supercronic/cron >> /var/log/supercronic-debian.log 2>&1 &' >> /start.sh && \
    echo 'touch /var/log/supercronic-root.log && chmod 664 /var/log/supercronic-root.log' >> /start.sh && \
    echo '/usr/local/bin/supercronic /root/.supercronic/cron >> /var/log/supercronic-root.log 2>&1 &' >> /start.sh && \
    echo 'echo "Supercronic started for debian and root."' >> /start.sh && \
    echo '# Export ENVIRONMENT globally for all shells' >> /start.sh && \
    echo 'if [ -n "$ENVIRONMENT" ]; then' >> /start.sh && \
    echo '  echo "export ENVIRONMENT=\"$ENVIRONMENT\"" > /etc/profile.d/environment.sh' >> /start.sh && \
    echo '  chmod 644 /etc/profile.d/environment.sh' >> /start.sh && \
    echo 'fi' >> /start.sh && \
    echo '# Keep container running and switch to debian user for exec sessions' >> /start.sh && \
    echo 'echo "Container ready. Default user: debian"' >> /start.sh && \
    echo 'tail -f /dev/null' >> /start.sh && \
    chmod +x /start.sh && \
# Create a wrapper for bash that switches to debian user
    mv /bin/bash /bin/bash.real && \
    echo '#!/bin/bash.real' > /bin/bash && \
    echo '# Source ENVIRONMENT for all shells' >> /bin/bash && \
    echo '[ -r /etc/profile.d/environment.sh ] && . /etc/profile.d/environment.sh' >> /bin/bash && \
    echo '# If we are root and in an interactive shell (not SSH), switch to debian' >> /bin/bash && \
    echo '# But respect if the user was explicitly set via docker exec --user=root' >> /bin/bash && \
    echo 'if [ "$(id -u)" = "0" ] && [ -t 0 ] && [ "$BASH_EXECUTION_STRING" = "" ] && [ -z "$SSH_CONNECTION" ] && [ -z "$SSH_CLIENT" ] && [ "$USER" != "root" ]; then' >> /bin/bash && \
    echo '  exec /bin/bash.real -c "su - debian"' >> /bin/bash && \
    echo 'else' >> /bin/bash && \
    echo '  exec /bin/bash.real "$@"' >> /bin/bash && \
    echo 'fi' >> /bin/bash && \
    chmod +x /bin/bash

# Set environment variables
#ENV PATH="/opt/incus/bin/:${PATH}"
#ENV INCUS_EDK2_PATH="/opt/incus/share/qemu/"
#ENV LD_LIBRARY_PATH="/opt/incus/lib/"
#ENV INCUS_LXC_TEMPLATE_CONFIG="/opt/incus/share/lxc/config/"
#ENV INCUS_DOCUMENTATION="/opt/incus/doc/"
#ENV INCUS_LXC_HOOK="/opt/incus/share/lxc/hooks/"
#ENV INCUS_AGENT_PATH="/opt/incus/agent/"

EXPOSE 22 2375

VOLUME /var/lib/incus /var/lib/docker /home/debian /root

# Run the start script using real bash (skip the wrapper)
CMD ["/bin/bash.real", "/start.sh"]

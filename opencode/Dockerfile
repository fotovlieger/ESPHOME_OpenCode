FROM ghcr.io/anomalyco/opencode:latest

USER root

RUN apk add --no-cache \
    openssh-client \
    git \
    github-cli \
    curl \
    jq \
    bash \
    sudo

# Create opencode group and user with UID/GID 1000 if not present
RUN getent group 1000 || addgroup -g 1000 opencode && \
    getent passwd 1000 || adduser -u 1000 -G opencode -s /bin/bash -D opencode

# Enable passwordless sudo for software installation
RUN echo "opencode ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/opencode && \
    chmod 0440 /etc/sudoers.d/opencode

# Copy SSH config globally
COPY ssh_config /etc/ssh/ssh_config

# Setup home directory and SSH permissions for user 1000
RUN mkdir -p /home/opencode/.ssh && \
    chown -R 1000:1000 /home/opencode && \
    chmod 700 /home/opencode/.ssh

# Toolchain wrapper
COPY toolchain /usr/local/bin/toolchain
RUN chmod +x /usr/local/bin/toolchain

USER 1000:1000
WORKDIR /workspace

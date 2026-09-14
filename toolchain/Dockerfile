FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    wget \
    unzip \
    build-essential \
    cmake \
    ninja-build \
    openssh-server \
    sudo \
    usbutils \
    && rm -rf /var/lib/apt/lists/*


# Python virtual environment
RUN python3 -m venv /opt/esphome

RUN /opt/esphome/bin/pip install --upgrade pip setuptools wheel

RUN /opt/esphome/bin/pip install \
    esphome \
    esptool


# User waarmee SSH draait (UID/GID 1000, gelijk aan host)
# Ubuntu 24.04 heeft al een 'ubuntu' user op 1000:1000; verwijder die eerst
RUN userdel -r ubuntu 2>/dev/null || true && \
    groupdel ubuntu 2>/dev/null || true
RUN groupadd -g 1000 toolchain && \
    useradd -m -u 1000 -g toolchain -s /bin/bash toolchain
RUN echo 'toolchain:toolchain' | chpasswd

RUN mkdir -p /run/sshd
RUN mkdir -p /workspace

RUN chown -R toolchain:toolchain /workspace


# ESPHome beschikbaar voor alle users
RUN ln -s /opt/esphome/bin/esphome /usr/local/bin/esphome
RUN ln -s /opt/esphome/bin/esptool /usr/local/bin/esptool


COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh


EXPOSE 22
ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

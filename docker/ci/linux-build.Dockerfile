ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION}

ARG DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        cmake \
        python3-pip \
        build-essential \
        pkg-config \
        binutils \
        gcc-multilib \
        g++-multilib \
        libssl-dev:i386 \
        tar \
    && pip3 install --no-cache-dir "cmake==3.31.6" \
    && cmake --version \
    && rm -rf /var/lib/apt/lists/*

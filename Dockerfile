# Base image which contains global dependencies
FROM ubuntu:18.04 as base
WORKDIR /workdir
RUN mkdir /workdir/ncs
RUN mkdir /data
# System dependencies
RUN apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install wget curl
# GCC ARM Embed
RUN mkdir /data/gcc-arm && \
    wget -q 'https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2?revision=bc2c96c0-14b5-4bb4-9f18-bceb4050fee7?product=GNU%20Arm%20Embedded%20Toolchain,64-bit,,Linux,7-2018-q2-update' \
    -O /data/gcc-arm/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2 && \
    tar xjf /data/gcc-arm/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2
ENV ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
ENV GNUARMEMB_TOOLCHAIN_PATH=/workdir/gcc-arm-none-eabi-7-2018-q2-update
# Device Tree Compile 1.4.7
RUN mkdir -p /data/device-tree-compiler/ && \
    wget -q 'http://mirrors.kernel.org/ubuntu/pool/main/d/device-tree-compiler/device-tree-compiler_1.4.7-3_amd64.deb' \
        -O /data/device-tree-compiler/device-tree-compiler_1.4.7-3_amd64.deb && \
    dpkg -i /data/device-tree-compiler/device-tree-compiler_1.4.7-3_amd64.deb
# Latest PIP
RUN apt-get -y install python3-pip && \
    python3 -m pip install -U pip
# Zephyr dependencies
RUN apt-get -y install ninja-build gperf git python3-setuptools && \
    python3 -m pip install -U setuptools && \
    pip3 install cmake wheel && \
    pip3 install -U --pre west && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually \
    python3 -m pip install --ignore-installed -U PyYAML
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8  
# MCU boot fixes: it will fail if python-cryptography or python3-cryptography are installed 
RUN apt-get -y remove python-cryptography python3-cryptography
# Rust+Cargo
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=~/.local/bin:/usr/share/rust/.cargo/bin:$PATH

# Build image, contains project-specific dependencies
FROM base
ADD . /workdir/ncs/nrf
# Zephyr dependencies
RUN cd /workdir/ncs/nrf && \
    west init -l && \
    west update && \
    cd .. && \
    pip3 install pc_ble_driver_py && \
    pip3 install -r zephyr/scripts/requirements.txt && \
    pip3 install -r nrf/scripts/requirements.txt && \
    pip3 install -r bootloader/mcuboot/scripts/requirements.txt
RUN mkdir /workdir/.cache
ENV XDG_CACHE_HOME=/workdir/.cache

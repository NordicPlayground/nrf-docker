# Base image which contains global dependencies
FROM ubuntu:18.04 as base
WORKDIR /workdir

# System dependencies
RUN mkdir /workdir/ncs && \
    apt-get -y update && apt-get -y upgrade && apt-get -y install \
        wget \
        python3-pip \
        ninja-build \
        gperf \
        git \
        python3-setuptools && \
    apt-get -y remove python-cryptography python3-cryptography && \
    apt-get -y clean && apt-get -y autoremove && \
    # GCC ARM Embed Toolchain
    wget -qO- \
    'https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/gcc-arm-none-eabi-7-2018-q2-update-linux.tar.bz2?revision=bc2c96c0-14b5-4bb4-9f18-bceb4050fee7?product=GNU%20Arm%20Embedded%20Toolchain,64-bit,,Linux,7-2018-q2-update' \
    | tar xj && \
    mkdir tmp && cd tmp && \
    # Device Tree Compiler 1.4.7
    wget -q http://mirrors.edge.kernel.org/ubuntu/pool/main/d/device-tree-compiler/device-tree-compiler_1.4.7-3ubuntu2_amd64.deb && \
    # Nordic command line tools
    wget -qO- https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-7-0/nRFCommandLineTools1070Linuxamd64tar.gz \
    | tar xz && \
    dpkg -i *.deb && \
    cd .. && rm -rf tmp && \
    # Latest PIP & Python dependencies
    python3 -m pip install -U pip && \
    python3 -m pip install -U setuptools && \
    pip3 install cmake wheel && \
    pip3 install -U west && \
    pip3 install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML

# Build image, contains project-specific dependencies
FROM base
COPY . /workdir/ncs/nrf
RUN \
    # Zephyr requirements of nrf
    cd /workdir/ncs/nrf; west init -l && \
    cd /workdir/ncs; west update && \
    pip3 install -r zephyr/scripts/requirements.txt && \
    pip3 install -r nrf/scripts/requirements.txt && \
    pip3 install -r bootloader/mcuboot/scripts/requirements.txt && \
    echo "source /workdir/ncs/zephyr/zephyr-env.sh" >> ~/.bashrc && \
    mkdir /workdir/.cache && \
    rm -rf /workdir/ncs/nrf

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV XDG_CACHE_HOME=/workdir/.cache
ENV ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
ENV GNUARMEMB_TOOLCHAIN_PATH=/workdir/gcc-arm-none-eabi-7-2018-q2-update

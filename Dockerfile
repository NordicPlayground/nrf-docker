# Base image which contains global dependencies
FROM ubuntu:20.04 as base
WORKDIR /workdir

# System dependencies
RUN mkdir /workdir/ncs && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        wget \
        python3-pip \
        ninja-build \
        gperf \
        git \
        python3-setuptools \
        libncurses5 libncurses5-dev \
        libyaml-dev libfdt1 && \
    apt-get -y remove python-cryptography python3-cryptography && \
    apt-get -y clean && apt-get -y autoremove && \
    # GCC ARM Embed Toolchain
    wget -qO- \
    'https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2?revision=108bd959-44bd-4619-9c19-26187abf5225&la=en&hash=E788CE92E5DFD64B2A8C246BBA91A249CB8E2D2D' \
    | tar xj && \
    mkdir tmp && cd tmp && \
    # Device Tree Compiler 1.5.1 (for Ubuntu 20.04)
    # Releases: https://git.kernel.org/pub/scm/utils/dtc/dtc.git
    wget -q http://archive.ubuntu.com/ubuntu/pool/main/d/device-tree-compiler/device-tree-compiler_1.5.1-1_amd64.deb && \
    # Nordic command line tools
    # Releases: https://www.nordicsemi.com/Software-and-tools/Development-Tools/nRF-Command-Line-Tools/Download
    wget -qO- https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-12-1/nRFCommandLineTools10121Linuxamd64tar.gz \
    | tar xz && \
    dpkg -i *.deb && \
    cd .. && rm -rf tmp && \
    # Latest PIP & Python dependencies
    python3 -m pip install -U pip && \
    python3 -m pip install -U setuptools && \
    python3 -m pip install cmake wheel && \
    python3 -m pip install -U west==0.9.0 && \
    python3 -m pip install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML && \
    # ClangFormat
    python3 -m pip install -U six && \
    apt-get -y install clang-format-9 && \
    ln -s /usr/bin/clang-format-9 /usr/bin/clang-format && \
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/master/.clang-format > /workdir/.clang-format

# Build image, contains project-specific dependencies
FROM base
COPY . /workdir/ncs/nrf
RUN \
    # Zephyr requirements of nrf
    cd /workdir/ncs/nrf && west init -l && \
    cd /workdir/ncs && west update && \
    python3 -m pip install -r zephyr/scripts/requirements.txt && \
    python3 -m pip install -r nrf/scripts/requirements.txt && \
    python3 -m pip install -r bootloader/mcuboot/scripts/requirements.txt && \
    echo "source /workdir/ncs/zephyr/zephyr-env.sh" >> ~/.bashrc && \
    mkdir /workdir/.cache

ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV XDG_CACHE_HOME=/workdir/.cache
ENV ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
ENV GNUARMEMB_TOOLCHAIN_PATH=/workdir/gcc-arm-none-eabi-9-2019-q4-major

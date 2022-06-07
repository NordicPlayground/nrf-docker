FROM ubuntu:20.04 as base
WORKDIR /workdir

ARG arch=amd64
ARG zephyr_toolchain_release=0.14.2

# System dependencies
RUN mkdir /workdir/project && \
    mkdir /workdir/.cache && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        wget \
        python3-pip \
        ninja-build \
        gperf \
        git \
        unzip \
        python3-setuptools \
        libncurses5 libncurses5-dev \
        libyaml-dev libfdt1 \
        libusb-1.0-0-dev udev \
        device-tree-compiler=1.5.1-1 \
        ruby && \
    apt-get -y clean && apt-get -y autoremove && \
    #
    # Latest PIP & Python dependencies
    #
    python3 -m pip install -U pip && \
    python3 -m pip install -U setuptools && \
    python3 -m pip install cmake>=3.20.0 wheel && \
    python3 -m pip install -U west==0.12.0 && \
    python3 -m pip install -U nrfutil && \
    python3 -m pip install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML && \
    #
    # ClangFormat
    #
    python3 -m pip install -U six && \
    apt-get -y install clang-format-9 && \
    ln -s /usr/bin/clang-format-9 /usr/bin/clang-format && \
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/main/.clang-format > /workdir/.clang-format && \
    #
    # Nordic command line tools
    #
    echo "Target architecture: $arch" && \
    case $arch in \
        "amd64") \
            NCLT_URL="https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-16-0/nrf-command-line-tools-10.16.0_Linux-amd64.tar.gz" \
            ;; \
        "arm64") \
            NCLT_URL="https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-16-0/nrf-command-line-tools-10.16.0_Linux-arm64.tar.gz" \
            ;; \
    esac && \
    # Releases: https://www.nordicsemi.com/Software-and-tools/Development-Tools/nRF-Command-Line-Tools/Download
    if [ ! -z "$NCLT_URL" ]; then \
        mkdir tmp && cd tmp && \
        wget -qO - "${NCLT_URL}" | tar xz && \
        DEBIAN_FRONTEND=noninteractive apt-get -y install ./*.deb && \
        cd .. && rm -rf tmp ; \
    else \
        echo "Skipping nRF Command Line Tools (not available for $arch)" ; \
    fi && \
    #
    # Zephyr Toolchain
    #
    echo "Target architecture: $arch" && \
    case $arch in \
        "amd64") \
            ZEPHYR_TOOLCHAIN_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${zephyr_toolchain_release}/zephyr-sdk-${zephyr_toolchain_release}_linux-x86_64.tar.gz" \
            ;; \
        "arm64") \
            ZEPHYR_TOOLCHAIN_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${zephyr_toolchain_release}/zephyr-sdk-${zephyr_toolchain_release}_linux-aarch64.tar.gz" \
            ;; \
        *) \
            echo "Unsupported target architecture: \"$arch\"" >&2 && \
            exit 1 ;; \
    esac && \
    wget -qO - "${ZEPHYR_TOOLCHAIN_URL}" | tar xz && \
    cd /workdir/zephyr-sdk-${zephyr_toolchain_release} && yes | ./setup.sh

# Download sdk-nrf and west dependencies to install pip requirements
FROM base
ARG sdk_nrf_revision=main
RUN \
    mkdir tmp && cd tmp && \
    west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_revision} && \
    west update --narrow -o=--depth=1 && \
    python3 -m pip install -r zephyr/scripts/requirements.txt && \
    python3 -m pip install -r nrf/scripts/requirements.txt && \
    python3 -m pip install -r bootloader/mcuboot/scripts/requirements.txt && \
    cd .. && rm -rf tmp

WORKDIR /workdir/project
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV XDG_CACHE_HOME=/workdir/.cache
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/workdir/zephyr-sdk-${zephyr_toolchain_release}
ENV ZEPHYR_BASE=/workdir/project/zephyr
ENV PATH="${ZEPHYR_BASE}/scripts:${PATH}"

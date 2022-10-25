FROM ubuntu:20.04 as base
WORKDIR /workdir

ARG arch=amd64
ARG ZEPHYR_TOOLCHAIN_VERSION=0.15.1
ARG WEST_VERSION=0.14.0
ARG NRF_UTIL_VERSION=6.1.7
ARG NORDIC_COMMAND_LINE_TOOLS_VERSION="Versions-10-x-x/10-18-0/nrf-command-line-tools-10.18.0"

# System dependencies
RUN mkdir /workdir/project && \
    mkdir /workdir/.cache && \
    apt-get -y update && \
    apt-get -y upgrade && \
    apt-get -y install \
        wget \
        python3-pip \
        python3-venv \
        ninja-build \
        gperf \
        git \
        unzip \
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
    python3 -m pip install -U pipx && \
    python3 -m pip install -U setuptools && \
    python3 -m pip install 'cmake>=3.20.0' wheel && \
    python3 -m pip install -U "west==${WEST_VERSION}" && \
    python3 -m pip install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML && \
    #
    # Isolated command line tools
    # No nrfutil 6+ release for arm64 (M1/M2 Macs) and Python 3, yet: https://github.com/NordicSemiconductor/pc-ble-driver-py/issues/227
    #
    case $arch in \
    "amd64") \
        PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin \
        pipx install "nrfutil==${NRF_UTIL_VERSION}" \
        ;; \
    esac && \
    #
    # ClangFormat
    #
    python3 -m pip install -U six && \
    apt-get -y install clang-format-9 && \
    ln -s /usr/bin/clang-format-9 /usr/bin/clang-format && \
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/main/.clang-format > /workdir/.clang-format && \
    #
    # Nordic command line tools
    # Releases: https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools/download
    #
    echo "Target architecture: $arch" && \
    case $arch in \
        "amd64") \
            NCLT_URL="https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/${NORDIC_COMMAND_LINE_TOOLS_VERSION}_Linux-amd64.tar.gz" \
            ;; \
        "arm64") \
            NCLT_URL="https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/${NORDIC_COMMAND_LINE_TOOLS_VERSION}_Linux-arm64.tar.gz" \
            ;; \
    esac && \
    echo "NCLT_URL=${NCLT_URL}" && \
    # Releases: https://www.nordicsemi.com/Software-and-tools/Development-Tools/nRF-Command-Line-Tools/Download
    if [ ! -z "$NCLT_URL" ]; then \
        mkdir tmp && cd tmp && \
        wget -qO - "${NCLT_URL}" | tar --no-same-owner -xz && \
        # Install included JLink
        DEBIAN_FRONTEND=noninteractive apt-get -y install ./*.deb && \
        # Install nrf-command-line-tools
        cp -r ./nrf-command-line-tools /opt && \
        ln -s /opt/nrf-command-line-tools/bin/nrfjprog /usr/local/bin/nrfjprog && \
        ln -s /opt/nrf-command-line-tools/bin/mergehex /usr/local/bin/mergehex && \
        cd .. && rm -rf tmp ; \
    else \
        echo "Skipping nRF Command Line Tools (not available for $arch)" ; \
    fi && \
    #
    # Zephyr Toolchain
    # Releases: https://github.com/zephyrproject-rtos/sdk-ng/releases
    #
    echo "Target architecture: $arch" && \
    echo "Zephyr Toolchain version: ${ZEPHYR_TOOLCHAIN_VERSION}" && \
    case $arch in \
        "amd64") \
            ZEPHYR_TOOLCHAIN_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_linux-x86_64.tar.gz" \
            ;; \
        "arm64") \
            ZEPHYR_TOOLCHAIN_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_TOOLCHAIN_VERSION}/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION}_macos-aarch64.tar.gz" \
            ;; \
        *) \
            echo "Unsupported target architecture: \"$arch\"" >&2 && \
            exit 1 ;; \
    esac && \
    echo "ZEPHYR_TOOLCHAIN_URL=${ZEPHYR_TOOLCHAIN_URL}" && \
    wget -qO - "${ZEPHYR_TOOLCHAIN_URL}" | tar xz && \
    mv /workdir/zephyr-sdk-${ZEPHYR_TOOLCHAIN_VERSION} /workdir/zephyr-sdk && cd /workdir/zephyr-sdk && yes | ./setup.sh

# Download sdk-nrf and west dependencies to install pip requirements
FROM base
ARG sdk_nrf_revision=main
RUN \
    mkdir tmp && cd tmp && \
    west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_revision} && \
    west update --narrow -o=--depth=1 && \
    echo "Installing requirements: zephyr/scripts/requirements.txt" && \
    python3 -m pip install -r zephyr/scripts/requirements.txt && \
    case $sdk_nrf_revision in \
        "v1.4-branch") \
            echo "Installing requirements: nrf/scripts/requirements.txt" && \
            python3 -m pip install -r nrf/scripts/requirements.txt \
        ;; \
        *) \
            # Install only the requirements needed for building firmware, not documentation
            echo "Installing requirements: nrf/scripts/requirements-base.txt" && \
            python3 -m pip install -r nrf/scripts/requirements-base.txt && \
            echo "Installing requirements: nrf/scripts/requirements-build.txt" && \
            python3 -m pip install -r nrf/scripts/requirements-build.txt \
        ;; \
    esac && \
    echo "Installing requirements: bootloader/mcuboot/scripts/requirements.txt" && \
    python3 -m pip install -r bootloader/mcuboot/scripts/requirements.txt && \
    cd .. && rm -rf tmp

WORKDIR /workdir/project
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8
ENV XDG_CACHE_HOME=/workdir/.cache
ENV ZEPHYR_TOOLCHAIN_VARIANT=zephyr
ENV ZEPHYR_SDK_INSTALL_DIR=/workdir/zephyr-sdk
ENV ZEPHYR_BASE=/workdir/project/zephyr
ENV PATH="${ZEPHYR_BASE}/scripts:${PATH}"
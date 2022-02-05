# Base image which contains global dependencies
FROM ubuntu:20.04 as base
WORKDIR /workdir

# System dependencies
ARG arch=amd64
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
    # GCC ARM Embed Toolchain
    echo "Target architecture: $arch" && \
    case $arch in \
        "amd64") \
            NCLT_URL="https://www.nordicsemi.com/-/media/Software-and-other-downloads/Desktop-software/nRF-command-line-tools/sw/Versions-10-x-x/10-15-0/nrf-command-line-tools-10.15.0_amd.zip" \
            ARM_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2?revision=108bd959-44bd-4619-9c19-26187abf5225&la=en&hash=E788CE92E5DFD64B2A8C246BBA91A249CB8E2D2D" \
            ;; \
        "arm64") \
            NCLT_URL="" \
            ARM_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-aarch64-linux.tar.bz2?revision=4583ce78-e7e7-459a-ad9f-bff8e94839f1&hash=CF9005177C5564B8A88F71AF541808EB" \
            ;; \
        *) \
            echo "Unsupported TARGETARCH: \"$TARGETARCH\"" >&2 && \
            exit 1 ;; \
    esac && \
    wget -qO - "${ARM_URL}" | tar xj && \
    # Nordic command line tools
    # Releases: https://www.nordicsemi.com/Software-and-tools/Development-Tools/nRF-Command-Line-Tools/Download
    # Doesn't exist for arm64, but not necessary for building
    if [ ! -z "$NCLT_URL" ]; then \
        mkdir tmp && cd tmp && \
        wget -q "${NCLT_URL}" && \
        unzip nrf-command-line-tools-*.zip && \
        tar xzf nrf-command-line-tools-*.tar.gz && \
        dpkg -i *.deb && \
        cd .. && rm -rf tmp ; \
    else \
        echo "Skipping nRF Command Line Tools (not available for $arch)" ; \
    fi && \
    # Latest PIP & Python dependencies
    python3 -m pip install -U pip && \
    python3 -m pip install -U setuptools && \
    python3 -m pip install cmake>=3.20.0 wheel && \
    python3 -m pip install -U west==0.12.0 && \
    python3 -m pip install -U nrfutil && \
    python3 -m pip install pc_ble_driver_py && \
    # Newer PIP will not overwrite distutils, so upgrade PyYAML manually
    python3 -m pip install --ignore-installed -U PyYAML && \
    # ClangFormat
    python3 -m pip install -U six && \
    apt-get -y install clang-format-9 && \
    ln -s /usr/bin/clang-format-9 /usr/bin/clang-format && \
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/main/.clang-format > /workdir/.clang-format

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
ENV ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
ENV GNUARMEMB_TOOLCHAIN_PATH=/workdir/gcc-arm-none-eabi-9-2019-q4-major
ENV ZEPHYR_BASE=/workdir/project/zephyr
ENV PATH="${ZEPHYR_BASE}/scripts:${PATH}"

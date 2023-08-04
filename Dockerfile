FROM ubuntu:22.04 as base
WORKDIR /workdir

ARG sdk_nrf_version=v2.4.0
ARG sdk_nrf_commit
ARG NORDIC_COMMAND_LINE_TOOLS_VERSION="10-21-0/nrf-command-line-tools-10.21.0"
ARG arch=amd64

ENV DEBIAN_FRONTEND=noninteractive

RUN <<EOT
    apt-get -y update
    apt-get -y upgrade
    apt-get -y install wget unzip
EOT

# Install toolchain
RUN <<EOT
    wget -q https://developer.nordicsemi.com/.pc-tools/nrfutil/x64-linux/nrfutil
    mv nrfutil /usr/local/bin
    chmod +x /usr/local/bin/nrfutil
    nrfutil install toolchain-manager
    nrfutil toolchain-manager install --ncs-version ${sdk_nrf_version}
    nrfutil toolchain-manager list
EOT

#
# ClangFormat
#
RUN <<EOT
    apt-get -y install clang-format
    sdk_nrf_branch=${sdk_nrf_version}
    if [[ $sdk_nrf_version != "main" ]]; then \
        sdk_nrf_branch=${sdk_nrf_branch}-branch; \
    fi
    wget -qO- https://raw.githubusercontent.com/nrfconnect/sdk-nrf/${sdk_nrf_branch}-branch/.clang-format > /workdir/.clang-format
EOT

# Nordic command line tools
# Releases: https://www.nordicsemi.com/Products/Development-tools/nrf-command-line-tools/download
RUN <<EOT
    NCLT_BASE=https://nsscprodmedia.blob.core.windows.net/prod/software-and-other-downloads/desktop-software/nrf-command-line-tools/sw/versions-10-x-x
    echo "Host architecture: $arch"
    case $arch in \
        "amd64") \
            NCLT_URL="${NCLT_BASE}/${NORDIC_COMMAND_LINE_TOOLS_VERSION}_linux-amd64.tar.gz" \
            ;; \
        "arm64") \
            NCLT_URL="${NCLT_BASE}/${NORDIC_COMMAND_LINE_TOOLS_VERSION}_linux-arm64.tar.gz" \
            ;; \
    esac
    echo "NCLT_URL=${NCLT_URL}"
    if [ ! -z "$NCLT_URL" ]; then \
        mkdir tmp && cd tmp
        wget -qO - "${NCLT_URL}" | tar --no-same-owner -xz
        # Install included JLink
        mkdir /opt/SEGGER
        tar xzf JLink_*.tgz -C /opt/SEGGER
        mv /opt/SEGGER/JLink* /opt/SEGGER/JLink
        # Install nrf-command-line-tools
        cp -r ./nrf-command-line-tools /opt
        ln -s /opt/nrf-command-line-tools/bin/nrfjprog /usr/local/bin/nrfjprog
        ln -s /opt/nrf-command-line-tools/bin/mergehex /usr/local/bin/mergehex
        cd .. && rm -rf tmp ; \
    else \
        echo "Skipping nRF Command Line Tools (not available for $arch)" ; \
    fi
EOT

# Prepare image with a ready to use build environment
SHELL ["nrfutil","toolchain-manager","launch","/bin/bash","--","-c"]
RUN <<EOT
    west init -m https://github.com/nrfconnect/sdk-nrf --mr ${sdk_nrf_version} .
    if [[ $sdk_nrf_commit =~ "^[a-fA-F0-9]{32}$" ]]; then \
        git checkout ${sdk_nrf_version}; \
    fi
    west update --narrow -o=--depth=1
EOT

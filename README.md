# Building NCS applications with Docker

![Publish Docker](https://github.com/coderbyheart/fw-nrfconnect-nrf-docker/workflows/Publish%20Docker/badge.svg?branch=saga)
(_the [Docker image](https://hub.docker.com/r/coderbyheart/fw-nrfconnect-nrf-docker) is build against [NCS](https://github.com/nrfconnect/sdk-nrf) `main`, `v1.7-branch`, `v1.6-branch`, `v1.5-branch`, and `v1.4-branch` every night._)

> :information_source: Read more about this aproach [here](https://devzone.nordicsemi.com/nordic/nrf-connect-sdk-guides/b/getting-started/posts/build-ncs-application-firmware-images-using-docker).

> :warning: The `latest` Docker image tag has been deleted. Use `coderbyheart/fw-nrfconnect-nrf-docker:main`.

![Docker + Zephyr -> merged.hex](./diagram.png)

Install `docker` on your operating system. On Windows you might want to use the [WSL subsystem](https://docs.docker.com/docker-for-windows/wsl-tech-preview/).

Clone the repo:

    git clone https://github.com/nrfconnect/sdk-nrf

Copy the Dockerfile to e.g. `/tmp/Dockerfile`, you might need to adapt the installation of [the requirements](./Dockerfile#L48-L51).

    wget https://raw.githubusercontent.com/coderbyheart/fw-nrfconnect-nrf-docker/saga/Dockerfile -O /tmp/Dockerfile

Build the image (this is only needed once):

    cd sdk-nrf
    docker build --no-cache=true -t fw-nrfconnect-nrf-docker -f /tmp/Dockerfile .

> _:green_apple: Note:_ To build for a Mac with the M1 architecture, you need to specify the `arm64` architecture when building: `--build-arg arch=arm64`.

Build the firmware for the `asset_tracker` application example:

    docker run --rm -v ${PWD}:/workdir/ncs/nrf fw-nrfconnect-nrf-docker \
      /bin/bash -c 'cd ncs/nrf/applications/asset_tracker && west build -p always -b nrf9160dk_nrf9160ns'

The firmware file will be in `applications/asset_tracker/build/zephyr/merged.hex`.

You only need to run this command to build.

## Full example

    git clone https://github.com/nrfconnect/sdk-nrf
    wget https://raw.githubusercontent.com/coderbyheart/fw-nrfconnect-nrf-docker/saga/Dockerfile -O /tmp/Dockerfile
    cd sdk-nrf
    docker build --no-cache=true -t fw-nrfconnect-nrf-docker -f /tmp/Dockerfile .
    docker run --rm -v ${PWD}:/workdir/ncs/nrf fw-nrfconnect-nrf-docker \
      /bin/bash -c 'cd ncs/nrf/applications/asset_tracker && west build -p always -b nrf9160dk_nrf9160ns'
    ls -la applications/asset_tracker/build/zephyr/merged.hex

## Using pre-built image from Dockerhub

> _Note:_ This is a convenient way to quickly build your firmware but using images from untrusted third-parties poses the risk of exposing your source code.

> _:green_apple: Note:_ The prebuilt images are not available for `arm64` architecture (Apple M1), because GitHub Actions don't have hosted runners with Apple M1 yet.

You can use the pre-built image [`coderbyheart/fw-nrfconnect-nrf-docker:main`](https://hub.docker.com/r/coderbyheart/fw-nrfconnect-nrf-docker).

    git clone https://github.com/nrfconnect/sdk-nrf
    cd sdk-nrf
    docker run --rm -v ${PWD}:/workdir/ncs/nrf coderbyheart/fw-nrfconnect-nrf-docker:main \
      /bin/bash -c 'cd ncs/nrf/applications/asset_tracker && west build -p always -b nrf9160dk_nrf9160ns'
    ls -la applications/asset_tracker/build/zephyr/merged.hex

### Build a Zephyr sample

This builds the `hci_uart` sample and stores the `hci_uart.hex` file in the current directory:

    docker run --rm -v ${PWD}:/workdir/ncs/nrf coderbyheart/fw-nrfconnect-nrf-docker:main \
        /bin/bash -c 'cd ncs/zephyr && west build samples/bluetooth/hci_uart -p always -b nrf9160dk_nrf52840 && \
        ls -la build/zephyr && cp build/zephyr/zephyr.hex /workdir/ncs/nrf/hci_uart.hex'

## Flashing

    cd sdk-nrf
    docker run --rm -v ${PWD}:/workdir/ncs/nrf --device=/dev/ttyACM0 --privileged \
      coderbyheart/fw-nrfconnect-nrf-docker:main \
      /bin/bash -c 'cd ncs/nrf/applications/asset_tracker && west flash'

## ClangFormat

The image comes with [ClangFormat](https://clang.llvm.org/docs/ClangFormat.html) and the [nRF Connect SDK formatting rules](https://github.com/nrfconnect/sdk-nrf/blob/main/.clang-format) so you can run for example

    docker run --name fw-nrfconnect-nrf-docker -d coderbyheart/fw-nrfconnect-nrf-docker tail -f /dev/null
    find ./src -type f -iname \*.h -o -iname \*.c \
        | xargs -I@ /bin/bash -c "\
            tmpfile=\$(mktemp /tmp/clang-formatted.XXXXXX) && \
            docker exec -i fw-nrfconnect-nrf-docker clang-format < @ > \$tmpfile && \
            cmp --silent @ \$tmpfile || (mv \$tmpfile @ && echo @ formatted.)"
    docker kill fw-nrfconnect-nrf-docker
    docker rm fw-nrfconnect-nrf-docker

to format your sources.

> _Note:_ Instead of having `clang-format` overwrite the source code file itself, the above command passes the source code file on stdin to clang-format and then overwrites it outside of the container. Otherwise the overwritten file will be owner by the root user (because the Docker daemon is run as root).

## Interactive usage

    cd sdk-nrf
    docker run -it --name fw-nrfconnect-nrf-docker -v ${PWD}:/workdir/ncs/nrf --device=/dev/ttyACM0 --privileged \
    coderbyheart/fw-nrfconnect-nrf-docker:main /bin/bash

Then, inside the container:

    cd ncs/nrf/applications/asset_tracker
    west build -p always -b nrf9160_pca20035ns
    west flash
    west build
    ...

Meanwhile, inside or outside of the container, you may modify the code and repeat the build/flash cycle.

Later after closing the container you may re-open it by name to continue where you left off:

    docker start -i fw-nrfconnect-nrf-docker

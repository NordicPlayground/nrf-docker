# Building NCS applications with Docker

![Publish Docker](https://github.com/coderbyheart/fw-nrfconnect-nrf-docker/workflows/Publish%20Docker/badge.svg?branch=saga)
(_the [Docker image](https://hub.docker.com/r/coderbyheart/fw-nrfconnect-nrf-docker) is build against [NCS](https://github.com/nrfconnect/sdk-nrf) `main`,`v1.8-branch`, `v1.7-branch`, `v1.6-branch`, `v1.5-branch`, and `v1.4-branch` every night._)

This project defines a Docker image that contains all dependencies to run `west` commands with the nRF Connect SDK. Bind mount the project folder you'd like to build, and the output will end up in the same folder (nested in build/zephyr subdir of the app).

> :information_source: Read more about this aproach [here](https://devzone.nordicsemi.com/nordic/nrf-connect-sdk-guides/b/getting-started/posts/build-ncs-application-firmware-images-using-docker).

> :warning: The `latest` Docker image tag has been deleted. Use `coderbyheart/fw-nrfconnect-nrf-docker:main`.

![Docker + Zephyr -> merged.hex](./diagram.png)

Install `docker` on your operating system. On Windows you might want to use the [WSL subsystem](https://docs.docker.com/docker-for-wi/workdir/project/ndows/wsl-tech-preview/).

## Setup

You can either build the image from this repository or use a pre-built one from Dockerhub.

### Build image locally

Clone the repo:

    git clone https://github.com/coderbyheart/fw-nrfconnect-nrf-docker

Build the image (this is only needed once):

    cd fw-nrfconnect-nrf-docker
    docker build -t fw-nrfconnect-nrf-docker --build-arg sdk_nrf_revision=v1.8-branch .

> _:green_apple: Note:_ To build for a Mac with the M1 architecture, you need to specify the `arm64` architecture when building: `--build-arg arch=arm64`.

> _Note:_ The `sdk_nrf_revision` build argument can be used to specify what version of the nRF Connect SDK that will be used when looking up dependencies with pip for the SDK and it's west dependency repositories. The value can be a git _tag_, _branch_ or _sha_ from the [nRF Connect SDK repository](https://github.com/nrfconnect/sdk-nrf).

### Use pre-built image from Dockerhub

> _Note:_ This is a convenient way to quickly build your firmware but using images from untrusted third-parties poses the risk of exposing your source code.

> _:green_apple: Note:_ The prebuilt images are not available for `arm64` architecture (Apple M1), because GitHub Actions don't have hosted runners with Apple M1 yet.

To use the pre-built image [`coderbyheart/fw-nrfconnect-nrf-docker:main`](https://hub.docker.com/r/coderbyheart/fw-nrfconnect-nrf-docker); just add `coderbyheart/` before the image name and `:tag` after. Replace `tag` with one of the [available tags](https://hub.docker.com/r/coderbyheart/fw-nrfconnect-nrf-docker/tags) on the Dockerhub image. The only difference between the tags are which Python dependencies are pre-installed in the image based on the different `requirements.txt` files from the nRF Connect SDK repository's west dependencies.

    docker run --rm -v ${PWD}:/workdir/project coderbyheart/fw-nrfconnect-nrf-docker:main ...

The rest of the documentation will use the local name `fw-nrfconnect-nrf-docker`, but any of them can use `coderbyheart/fw-nrfconnect-nrf-docker:main` (or a different tag) instead.

### Initialize and update west dependencies

Setting up the nRF Connect SDK to build sample applications and a stand-alone repository is a bit different, so we'll demonstrate both.

#### Using the nRF Connect SDK

    mkdir nrfconnect && cd nrfconnect
    docker run --rm -v ${PWD}:/workdir/project fw-nrfconnect-nrf-docker /bin/bash -c '\
        west init -m https://github.com/nrfconnect/sdk-nrf && \
        west update --narrow -o=--depth=1'

#### Using it with an out-of-tree repository

Because west installs the dependency repository in the parent-folder of the project folder we need to have an extra subfolder where the custom firmware code is located. Then the containing folder can be mounted when running the container and the output from west will be stored alongside the custom firmware folder. Here's an example folder layout for the `my-application`:

    build-with-nrf-connect-sdk
    ├── bootloader
    ├── mbedtls
    ├── modules
    ├── my-application
    ├── nrf
    ├── nrfxlib
    ├── test
    ├── tools
    └── zephyr

Now we can initialize the image for use with our out-of-tree firmware folder:

    mkdir build-with-nrf-connect-sdk && cd build-with-nrf-connect-sdk
    git clone https://github.com/my-org/my-application
    docker run --rm -v ${PWD}:/workdir/project fw-nrfconnect-nrf-docker /bin/bash -c '\
        cd my-application && \
        west init -l && \
        west update --narrow -o=--depth=1'

### Build the firmware

To demonstrate, we'll build the _asset_tracker_v2_ application from sdk-nrf:

    docker run --rm -v ${PWD}:/workdir/project \
        -w /workdir/project/nrf/applications/asset_tracker_v2 \
        fw-nrfconnect-nrf-docker \
        west build -p always -b nrf9160dk_nrf9160_ns

The firmware file will be located here: `nrf/applications/asset_tracker_v2/build/zephyr/merged.hex`. Because it's inside the folder that is bind mounted when running the image, it is also available outside of the Docker image.

> _Note:_ The `-p always` build argument is to do a pristine build. It is similar to cleaning the build folder and is used because it is less error-prone to a previous build with different configuration. To speed up subsequent build with the same configuration you can remove this argument to avoid re-building code that haven't been modified since the previous build.

To build a stand-alone project, just replace `-w /workdir/project/nrf/applications/asset_tracker_v2` with the name of the applications folder inside the docker container:

    # run from the build-with-nrf-connect-sdk
    docker run --rm -v ${PWD}:/workdir/project \
        -w /workdir/project/my-application \
        fw-nrfconnect-nrf-docker \
        west build -p always -b nrf9160dk_nrf9160_ns

## Full example

    # build docker image
    git clone https://github.com/coderbyheart/fw-nrfconnect-nrf-docker
    cd fw-nrfconnect-nrf-docker
    docker build -t fw-nrfconnect-nrf-docker --build-arg sdk_nrf_revision=v1.8-branch .
    cd ..

    # initialize sdk-nrf and build asset_tracker_v2 application
    mkdir nrfconnect && cd nrfconnect
    docker run --rm -v ${PWD}:/workdir/project fw-nrfconnect-nrf-docker /bin/bash -c '\
        west init -m https://github.com/nrfconnect/sdk-nrf --mr v1.8-branch && \
        west update --narrow -o=--depth=1 && \
        cd nrf/applications/asset_tracker_v2 && \
        west build -p always -b nrf9160dk_nrf9160_ns'
    ls -la nrf/applications/asset_tracker_v2/build/zephyr/merged.hex

> _Note:_ The `--mr` argument to `west init` specifies the manifest revision, which is the same as the SDK version. It can be a _branch_, _tag_ or a _sha_. It's recommended to select a recent stable version. Which will be tagged. See available [tags in the sdk-nrf repo](https://github.com/nrfconnect/sdk-nrf/tags).

### Build a Zephyr sample

This builds the `hci_uart` sample and stores the `hci_uart.hex` file in the current directory:

    # assumes `west init` and `west update` from before
    docker run --rm -v ${PWD}:/workdir/project coderbyheart/fw-nrfconnect-nrf-docker:main \
        west build zephyr/samples/bluetooth/hci_uart -p always -b nrf9160dk_nrf52840
    ls -la build/zephyr && cp build/zephyr/zephyr.hex ./hci_uart.hex

## Flashing

> _:Note:_ Docker for Mac OS and Windows does not have support for USB yet, so this will only work on Linux computers.

    # assumes asset_tracker_v2 built already (see above)
    docker run --rm -v ${PWD}:/workdir/project \
        -w /workdir/project//workdir/project/nrf/applications/asset_tracker_v2 \
        fw-nrfconnect-nrf-docker \
        --device=/dev/ttyACM0 --privileged \
        fw-nrfconnect-nrf-docker \
        west flash

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

    # from a folder you've initialized with west already
    docker run -it --name fw-nrfconnect-nrf-docker -v ${PWD}:/workdir/project \
        fw-nrfconnect-nrf-docker /bin/bash

> _Note:_ On Linux add `--device=/dev/ttyACM0 --privileged` to be able to flash from the Docker container.

Then, inside the container:

    cd nrf/applications/asset_tracker_v2
    west build -p always -b nrf9160dk_nrf9160_ns
    west flash # only works on linux - use nrf desktop tools on Windows/Mac OS
    west build
    ...

Meanwhile, inside or outside of the container, you may modify the code and repeat the build/flash cycle.

Later after closing the container you may re-open it by name to continue where you left off:

    docker start -i fw-nrfconnect-nrf-docker

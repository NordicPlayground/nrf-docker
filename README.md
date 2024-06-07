# Dockerfile example for building nRF Connect SDK applications on GitHub Actions

![Publish Docker](https://github.com/NordicPlayground/nrf-docker/workflows/Publish%20Docker/badge.svg?branch=saga)
(_the [Docker image](https://hub.docker.com/r/nordicplayground/nrfconnect-sdk) is build against [nRF Connect SDK](https://github.com/nrfconnect/sdk-nrf) `main`, and the last 5 release branches every night._)

![Docker + Zephyr -> merged.hex](./diagram.png)

This project defines a Docker image that contains all dependencies to run `west` commands with the nRF Connect SDK. Bind mount the project folder you'd like to build, and the output will end up in the same folder (nested in build/b0/zephyr subdir of the app).

The aim is to provide an example for a Docker image that can compile application and samples in a [nRF Connect SDK](https://github.com/nrfconnect/sdk-nrf) release branch, not to exactly replicate the software configuration used when the release was made.

More specificially, the purpose of this project is _not_ to provide stable images, but replicate what users are facing when they start developing with nRF Connect SDK (which itself does not provide a reproducible build environment). This is mitigated by the [Toolchain Manager](https://developer.nordicsemi.com/nRF_Connect_SDK/doc/latest/nrf/installation/assistant.html#install-toolchain-manager), which is available for command line usage.

However, provisioning an environment with the toolchain and an updated west environment still takes considerable time (around 10 minutes). Especially with matrix builds this will quickly add up. Therefore this project shows how to dockerize a ready-to-use `west build` command.

If you want stable Docker images or have custom needs, use the [Dockerfile](./Dockerfile) in this repository as an example to build your own Docker image.

For Matter applications, check out [nrfconnect-chip-docker](https://github.com/NordicPlayground/nrfconnect-chip-docker/).

For Zephyr applications, check out the [Zephyr Docker images](https://github.com/zephyrproject-rtos/docker-image/pkgs/container/ci#zephyr-docker-images).

## Setup

Install `docker` on your operating system. On Windows you might want to use the [WSL subsystem](https://docs.docker.com/docker-for-windows/wsl-tech-preview/).

You can either build the image from this repository or use a pre-built one from Dockerhub.

### Build image locally

Clone the repo:

```bash
git clone https://github.com/NordicPlayground/nrf-docker
```

Build the image (this is only needed once):

```bash
cd nrf-docker
docker build -t nrfconnect-sdk --build-arg sdk_nrf_version=v2.6-branch .
```

> [!NOTE]
> To build for a Mac with the M1 architecture, you need to specify the `arm64` architecture when building: `--build-arg arch=arm64`.

> [!NOTE]
> The `sdk_nrf_version` build argument can be used to specify what version of the nRF Connect SDK that will be used when looking up dependencies with pip for the SDK and it's west dependency repositories. The value can be a git _tag_, _branch_ or _sha_ from the [nRF Connect SDK repository](https://github.com/nrfconnect/sdk-nrf).

### Use pre-built image from Dockerhub

> [!NOTE]
> This is a convenient way to quickly build your firmware but using images from untrusted third-parties poses the risk of exposing your source code.
> There is no guarantee (e.g. cryptographic signature) about what this image contains.
> When publishing the image this project only ensures through automation that it can be used to build nRF Connect SDK examples.
> The entire image creation and publication is automated (build on GitHub Actions, and served by Dockerhub), which means there are multiple systems that can be compromised, during and after publication.
> No human is involved in verifying the image.
> In addition Docker images are not deterministic.
> At build time, dependencies are fetched from third-party sources and installed. These dependencies could also contain malicious code.
> If you are using this image you must be aware that you are using software from many untrusted sources with all the consequences that brings.

> [!NOTE]
> The prebuilt images are only available for `amd64` architecture (Linux).

To use the pre-built image [`nordicplayground/nrfconnect-sdk:main`](https://hub.docker.com/r/nordicplayground/nrfconnect-sdk); add `nordicplayground/` before the image name and `:tag` after. Replace `tag` with one of the [available tags](https://hub.docker.com/r/nordicplayground/nrfconnect-sdk/tags) on the Dockerhub image. The only difference between the tags are which Python dependencies are pre-installed in the image based on the different `requirements.txt` files from the nRF Connect SDK repository's west dependencies.

```bash
docker run --rm -v ${PWD}:/workdir/project nordicplayground/nrfconnect-sdk:main ...
```

The rest of the documentation will use the local name `nrfconnect-sdk`, but any of them can use `nordicplayground/nrfconnect-sdk:main` (or a different tag) instead.

### Build the firmware

To demonstrate, we'll build the _asset_tracker_v2_ application from the nRF Connect SDK:

```bash
docker run --rm \
    -v ${PWD}:/workdir/project \
    -w /workdir/nrf/applications/asset_tracker_v2 \
    nrfconnect-sdk \
    west build -p always -b nrf9160dk_nrf9160_ns --build-dir /workdir/project/build
```

The firmware file will be located here: `nrf/applications/asset_tracker_v2/build/b0/zephyr/merged.hex`. Because it's inside the folder that is bind mounted when running the image, it is also available outside of the Docker image.

> [!NOTE]
> The `-p always` build argument is to do a pristine build. It is similar to cleaning the build folder and is used because it is less error-prone to a previous build with different configuration. To speed up subsequent build with the same configuration you can remove this argument to avoid re-building code that haven't been modified since the previous build.

To build a stand-alone project, replace `-w /workdir/nrf/applications/asset_tracker_v2` with the name of the applications folder inside the docker container:

```bash
# run from the build-with-nrf-connect-sdk
docker run --rm -v ${PWD}:/workdir/project \
    nrfconnect-sdk \
    west build -p always -b nrf9160dk_nrf9160_ns\
```

## Full example

```bash
# build docker image
git clone https://github.com/NordicPlayground/nrf-docker
cd nrf-docker
docker build -t nrfconnect-sdk --build-arg sdk_nrf_version=v2.6-branch .
cd ..
```

### Build a Zephyr sample using the hosted image

This builds the `hci_uart` sample and stores the `hci_uart.hex` file in the current directory:

```bash
docker run --rm nordicplayground/nrfconnect-sdk:main \
    -v ${PWD}:/workdir/project \
    west build zephyr/samples/bluetooth/hci_uart -p always -b nrf9160dk_nrf52840 --build-dir /workdir/project/build
ls -la build/b0/zephyr && cp build/b0/zephyr/zephyr.hex ./hci_uart.hex
```

#### nRF5280 DK example

```bash
# Init and build in Docker
docker run --rm nordicplayground/nrfconnect-sdk:main \
  -v ${PWD}:/workdir/project \
  west build zephyr/samples/bluetooth/peripheral_ht -p always -b nrf52840dk_nrf52840 --build-dir /workdir/project/build

# Access build files
cp build/b0/zephyr/zephyr.hex peripheral_ht.hex
ls -la ./peripheral_ht.hex
```

## ClangFormat

The image comes with [ClangFormat](https://clang.llvm.org/docs/ClangFormat.html) and the [nRF Connect SDK formatting rules](https://github.com/nrfconnect/sdk-nrf/blob/main/.clang-format) so you can run for example

```bash
docker run --name nrfconnect-sdk -d nordicplayground/nrfconnect-sdk tail -f /dev/null
find ./src -type f -iname \*.h -o -iname \*.c \
    | xargs -I@ /bin/bash -c "\
        tmpfile=\$(mktemp /tmp/clang-formatted.XXXXXX) && \
        docker exec -i nrfconnect-sdk clang-format < @ > \$tmpfile && \
        cmp --silent @ \$tmpfile || (mv \$tmpfile @ && echo @ formatted.)"
docker kill nrfconnect-sdk
docker rm nrfconnect-sdk
```

to format your sources.

> [!NOTE]
> Instead of having `clang-format` overwrite the source code file itself, the above command passes the source code file on stdin to clang-format and then overwrites it outside of the container. Otherwise the overwritten file will be owner by the root user (because the Docker daemon is run as root).

## Interactive usage

```bash
docker run -it -v ${PWD}:/workdir/project \
    nrfconnect-sdk /bin/bash
```

Then, inside the container:

```bash
cd nrf/applications/asset_tracker_v2
west build -p always -b nrf9160dk_nrf9160_ns
...
```

Meanwhile, outside of the container, you may modify the code and repeat the build cycle.

Later after closing the container you may re-open it by name to continue where you left off:

```bash
docker start -i nrfconnect-sdk
```

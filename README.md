# Building NCS applications with Docker

![Docker + Zephyr -> merged.hex](./diagram.png)

Clone the repo: `git clone https://github.com/NordicPlayground/fw-nrfconnect-nrf`

Copy the Dockerfile to e.g. `/tmp/Dockerfile`, you might need to adapt the installation of [the requirements](./Dockerfile#L48-L51).

Build the image (this is only needed once):

    cd fw-nrfconnect-nrf
    docker build --no-cache=true -t ncs -f /tmp/Dockerfile .

Build the firmware for the `asset_tracker` application example:

    docker run --name ncs --rm -v ${PWD}:/workdir/ncs/fw-nrfconnect-nrf ncs \
      /bin/bash -c 'cd ncs/fw-nrfconnect-nrf/applications/asset_tracker; west build -p auto -b nrf9160_pca20035ns'

The firmware file will be in `applications/asset_tracker/build/zephyr/merged.hex`.

You only need to run this command to build.

## Full example

    cd /tmp
    git clone https://github.com/NordicPlayground/fw-nrfconnect-nrf
    wget https://raw.githubusercontent.com/coderbyheart/fw-nrfconnect-nrf-docker/saga/Dockerfile
    cd fw-nrfconnect-nrf
    docker build --no-cache=true -t ncs -f /tmp/Dockerfile .
    docker run --name ncs --rm -v /tmp/fw-nrfconnect-nrf:/workdir/ncs/fw-nrfconnect-nrf ncs \
      /bin/bash -c 'cd ncs/fw-nrfconnect-nrf/applications/asset_tracker; west build -p auto -b nrf9160_pca20035ns'
    ls -la applications/asset_tracker/build/zephyr/merged.hex
    
## Using prebuild image from Dockerhub

> *Note:* This is a convenient way to quickly build your firmware but using images from untrusted third-parties poses the risk of exposing your source code.

You can use the pre-build image [`coderbyheart/fw-nrfconnect-nrf-docker:latest`](
https://hub.docker.com/repository/docker/coderbyheart/fw-nrfconnect-nrf-docker)

    cd /tmp
    git clone https://github.com/NordicPlayground/fw-nrfconnect-nrf
    cd fw-nrfconnect-nrf
    docker run --name ncs --rm -v /tmp/fw-nrfconnect-nrf:/workdir/ncs/fw-nrfconnect-nrf coderbyheart/fw-nrfconnect-nrf-docker:latest \
      /bin/bash -c 'cd ncs/fw-nrfconnect-nrf/applications/asset_tracker; west build -p auto -b nrf9160_pca20035ns'
    ls -la applications/asset_tracker/build/zephyr/merged.hex

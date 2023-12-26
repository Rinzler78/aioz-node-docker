## Purpose

This sources allow to create docker image contains all necessary components to run aioz node.

For more informations on the aioz project lets go to => <https://aioz.network/>

Downloads and client installation are available at => <https://aioz.network/aioz-node>

## Table of contents

* [docker creation](#docker-creation)
  * [dockerFile](#dockerfile)
  * [Build instructions](#build-instructions)
  * [Before run](#before-run)
  * [Run instructions](#run-instructions)
  * [Public docker image](#public-docker-image)
* [Synology nas docker deployment](#synology-nas-docker-deployment)
  * [Install docker](#install-docker)
  * [Search aioznode image](#search-aioznode-image)
  * [Create datadir directory](#create-datadir-directory)
  * [Configure image and start container](#configure-image-and-start-container)
* [Support](#support)

## docker creation

### Dockerfile

#### Base container

This container is based on an ubuntu:latest.

#### Packages

Following packages are installed :

* wget => Allow to download the aioznode binary from github link => <https://github.com/AIOZNetwork/aioz-dcdn-cli-node/releases>
* curl and wget => Update aioznode

#### aioznode installation

aioznode binary is downloaded, put at /bin/aioznode and make executable.

#### Volumes

nodedata directory is created at root directory => /nodedata.
It must be linked to directory outside the container.

#### Start script

start.sh file is a bash script called at container startup.
It performs following actions :

* Check for newer version of aioznode at <https://github.com/AIOZNetwork/aioz-dcdn-cli-node/releases>
* Start aioznode binary

### Build instructions

docker build -t aioznode .

### Before run

#### nodedata directory

Create a directory on your docker host to be linked to the container datadir. Exemple : ~/MyDockers/aioznode/nodedata

### Run instructions

docker run command is :
[docker run -d \
-v {Your directory}:/datadir \
--restart=always \
--name aioznode -it aioznode](helper.docker.run.sh)

Where :

* {Your directory} => Your nodedata directory on the docker host

Exemple :
docker run -d \
-v docker/aioznode/nodadata:/nodedata \
--name aioznode -it aioznode

### Public docker image

Public container is available at <https://hub.docker.com/repository/docker/rinzlerfr/aioznode>

## Synology nas docker deployment

### Install docker

if not installed, go to the package center, search docker and install it.

### Search aioznode image

Go to docker GUI and search "rinzlerfr/aioznode" in the register page.
Once found download it.

### Create datadir directory

Using File station, create a directory on your syno to link to the container datadir. Exemple : docker/aioznode/nodedata

### Configure image and start container

Back to docker GUI, in Images. Select the "rinzlerfr/aioznode" image, and click launch.

* Give a name to your container. Exemple : aioznode
* Enable resources limitation (optional) :
-- Put processor priority to high.
-- Put 1024 MB limitation
* Click to advanced parameters
* Enable auto restart.

* Go to Volume, click Add directory, select the datadir directory created on your syno. Exemple : docker/aioznode/nodedata
-- Then put /nodedata on the rigth and validate

Then validate and launch the container.

## Support

Please consider donating to 0x4D11B64d9bb0652a92FCaD019d7Fc79f14821571 | aioz1f5gmvnvmkpjj4yhu45qe6l78nu2gy9t3mklmct if you are satisfied

Hav fun !! ;)

# Deploying Scalelite Docker Containers

Scalelite is released through Docker Images published on [DockerHub](https://hub.docker.com/r/blindsidenetwks/scalelite).

As part of the first release (v1.0) there are four images.

- blindsidenetwks/scalelite:[\<version tag>-nginx](#web-frontend-scalelite-api-and-scalelite-nginx)
- blindsidenetwks/scalelite:[\<version tag>-api](#web-frontend-scalelite-api-and-scalelite-nginx)
- blindsidenetwks/scalelite:[\<version tag>-poller](#meeting-status-poller-scalelite-poller)
- blindsidenetwks/scalelite:[\<version tag>-recording-importer](#recording-importer-scalelite-recording-importer)

But because Scalelite can be deployed in several different ways, and since the api, poller and recording-importer images are essetially the same base code (with a different starter), starting with v1.1 there is also a general referrenced only by the '<version tag>'.

- blindsidenetwks/scalelite:<version tag>

There are also some extra sets of images that include components for handling BigBlueButton 2.3 recordings, bundled in Alpine and Amazon Linux as the base.

- blindsidenetwks/scalelite:\<version tag>-bionic230-alpine
- blindsidenetwks/scalelite:\<version tag>-bionic230-alpine-nginx
- blindsidenetwks/scalelite:\<version tag>-bionic230-alpine-api
- blindsidenetwks/scalelite:\<version tag>-bionic230-alpine-poller
- blindsidenetwks/scalelite:\<version tag>-bionic230-alpine-recording-importer

and

- blindsidenetwks/scalelite:\<version tag>-bionic230-amazonlinux
- blindsidenetwks/scalelite:\<version tag>-bionic230-amazonlinux-nginx
- blindsidenetwks/scalelite:\<version tag>-bionic230-amazonlinux-api
- blindsidenetwks/scalelite:\<version tag>-bionic230-amazonlinux-poller
- blindsidenetwks/scalelite:\<version tag>-bionic230-amazonlinux-recording-importer

The recommended method to deploy Scalelite is to use systemd to start and manage the Docker containers. Some initial preparation is required on each host that will run Scalelite containers.

## Install Docker on the host system
To install the several components required by Scalelite, Docker must be installed on the host system.

To install Docker, please follow the instructions provided by Docker on their website:

https://docs.docker.com/install/linux/docker-ce/ubuntu/

## Common configuration for Docker host system
For communication between Scalelite containers, a private network should be created. To create a network with the default bridged mode, run:

`docker network create scalelite`

Create a file `/etc/default/scalelite` with the environment variables to configure the application. Reference the [Required Configuration](README.md#required) section for details as needed. For most deployments, you will need to include the following variables at a minimum.

```
URL_HOST
SECRET_KEY_BASE
LOADBALANCER_SECRET
DATABASE_URL
REDIS_URL
```

Add the following lines to configure the docker image tag to use and the location of the recording directory to mount into the containers:

```
SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton
```

**If Scalelite is responsible for serving via HTTPS**, you must add the following lines to enable HTTPs configuration:

```
NGINX_SSL=true
SCALELITE_NGINX_EXTRA_OPTS=--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly
```

Next you should Create a file `/etc/systemd/system/scalelite.target` with the content found in the [scalelite.target](systemd/scalelite.target) file. This unit is a helper to allow starting and stopping all of the Scalelite containers together.

And enable the target by running

`systemctl enable scalelite.target`

## Web Frontend (scalelite-api and scalelite-nginx)

The scalelite-api container holds the application code responsible for responding to BigBlueButton API requests. The scalelite-nginx container is responsible for SSL termination (if configured) and for serving recording playback files. Both containers must be colocated on the same host. For a high availability deployment, you can run multiple instances on different hosts behind an external HTTP load balancer.

Create a systemd unit file `/etc/systemd/system/scalelite-api.service` with the content found in the [scalelite-api.service](systemd/scalelite-api.service) file.

And enable it by running

`systemctl enable scalelite-api.service`

Create a systemd unit file `/etc/systemd/system/scalelite-nginx.service` with the content found in the [scalelite-nginx.service](systemd/scalelite-nginx.service) file.

And enable it by running systemctl

`systemctl enable scalelite-nginx.service`

You can now restart all scalelite services by running

`systemctl restart scalelite.target`

Afterwards, check the status with

`systemctl status scalelite-api.service scalelite-nginx.service`

to verify that the containers started correctly.

## Initialize the scalelite-api Database

If this is a fresh install, you can load the database schema into PostgreSQL by running this command:

`docker exec -it scalelite-api bin/rake db:setup`

You should restart all Scalelite services again afterwards by running

`systemctl restart scalelite.target`

## Meeting Status Poller (scalelite-poller)
The scalelite-poller container runs a process that periodically checks the reachability and load of BigBlueButton servers, and detects when meetings have ended.
Only a single poller is required in a deployment, but running multiple pollers will not cause any errors. It can be colocated on the same host system as the web frontend.

Create a systemd unit file `/etc/systemd/system/scalelite-poller.service` with the content found in the [scalelite-poller.service](systemd/scalelite-poller.service) file.

And enable it by running

`systemctl enable scalelite-poller.service`

You can now restart all scalelite services by running

`systemctl restart scalelite.target`

Afterwards, check the status with

`systemctl status scalelite-poller.service`

to verify that the containers started correctly.

## Recording Importer (scalelite-recording-importer)
The scalelite-recording-importer container runs a process that monitors for new recordings transferred to the spool directory from BigBlueButton servers. It unpacks the transferred recordings, adds the recording information to the Scalelite database, and places the recording files into the correct places so scalelite-nginx can serve the recordings.

You MUST run only one instance of the recording importer.

If you are doing a high-availability deployment of Scalelite, then the recording importer **MUST** be set up on a separate host from the web frontend.

If you are not doing a high-availability deployment of Scalelite, then you **MAY** colocate the web frontend and recording importer on the same host.

You **MAY** colocate the recording importer and meeting status poller on the same host.

Create a systemd unit file `/etc/systemd/system/scalelite-recording-importer.service` with the content found in the [scalelite-recording-importer.service](systemd/scalelite-recording-importer.service) file.

And enable it by running

`systemctl enable scalelite-recording-importer.service`

You can now restart all scalelite services by running

`systemctl restart scalelite.target`

Afterwards, check the status with

`systemctl status scalelite-recording-importer.service`

to verify that the containers started correctly.

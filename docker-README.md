# Deploying Scalelite Docker Containers
The recommended method to deploy this release of Scalelite is to use systemd to start and manage the Docker containers. Some initial preparation is required on each host that will run Scalelite containers.

## Install Docker on the host system
To install the several components required by Scalelite, Docker must be installed on the host system. 

To install Docker, please follow the instructions provided by Docker on their website: 

https://docs.docker.com/install/linux/docker-ce/ubuntu/

## Common configuration for Docker host system
For communication between Scalelite containers, a private network should be created. To create a network with the default bridged mode, run:

`docker network create scalelite`

Create the file `/etc/default/scalelite` with the environment variables to configure the application. Reference the [Configuration](README.md#configuration) section for details as needed. For most deployments, you will need to include the following variables at a minimum. 

```
URL_HOST
SECRET_KEY_BASE
LOADBALANCER_SECRET
DATABASE_URL
REDIS_URL
```

If Scalelite is responsible for serving via HTTPS, you must add the following lines to enable HTTPs configuration:

```
NGINX_SSL=true
SCALELITE_NGINX_EXTRA_OPTS=--mount type=bind,source=/etc/letsencrypt,target=/etc/nginx/ssl,readonly
```

Add the following lines to configure the docker image tag to use and the location of the recording directory to mount into the containers:

```
SCALELITE_TAG=v1
SCALELITE_RECORDING_DIR=/mnt/scalelite-recordings/var/bigbluebutton
```

Next you should create the file `/etc/systemd/system/scalelite.target` with the following contents. This unit is a helper to allow starting and stopping all of the Scalelite containers together.

```
[Unit]
Description=Scalelite
[Install]
WantedBy=multi-user.target
```

And enable the target by running

`systemctl enable scalelite.target`

## Web Frontend (scalelite-api and scalelite-nginx)
The scalelite-api container holds the application code responsible for responding to BigBlueButton API requests. The scalelite-nginx container is responsible for SSL termination (if configured) and for serving recording playback files. Both containers must be colocated on the same host. For a high availability deployment, you can run multiple instances on different hosts behind an external HTTP load balancer.

Create the systemd unit file `/etc/systemd/system/scalelite-api.service`

```
[Unit]
Description=Scalelite API
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-api
ExecStartPre=-/usr/bin/docker rm scalelite-api
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-api
ExecStart=/usr/bin/docker run --name scalelite-api --env-file /etc/default/scalelite --network scalelite blindsidenetwks/scalelite:${SCALELITE_TAG}-api
[Install]
WantedBy=scalelite.target
```
And enable it by running 

`systemctl enable scalelite-api.service`

Create the systemd unit file `/etc/systemd/system/scalelite-nginx.service`

```
[Unit]
Description=Scalelite Nginx
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
After=scalelite-api.service
Requires=scalelite-api.service
After=remote-fs.target
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-nginx
ExecStartPre=-/usr/bin/docker rm scalelite-nginx
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
ExecStart=/usr/bin/docker run --name scalelite-nginx --env-file /etc/default/scalelite --network scalelite --publish 80:80 --publish 443:443 --mount type=bind,source=${SCALELITE_RECORDING_DIR}/published,target=/var/bigbluebutton/published,readonly $SCALELITE_NGINX_EXTRA_OPTS blindsidenetwks/scalelite:${SCALELITE_TAG}-nginx
[Install]
WantedBy=scalelite.target
```

And enable it by running systemctl 

`systemctl enable scalelite-nginx.service`

You can now restart all scalelite services by running

`systemctl restart scalelite.target`

Afterwards, check the status with

`systemctl status scalelite-api.service scalelite-nginx.service`

to verify that the containers started correctly.

If this is a fresh install or you have not previously loaded the database schema into PostgreSQL, you can do that now by running this command:

`docker exec -it scalelite-api bin/rake db:setup`

You should restart all Scalelite services again afterwards by running 
`systemctl restart scalelite.target`

## Meeting Status Poller (scalelite-poller)
The scalelite-poller container runs a process that periodically checks the reachability and load of BigBlueButton servers, and detects when meetings have ended.
Only a single poller is required in a deployment, but running multiple pollers will not cause any errors. It can be colocated on the same host system as the web frontend.

Create the systemd unit file `/etc/systemd/system/scalelite-poller.service`

```
[Unit]
Description=Scalelite Meeting Status Poller
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
After=scalelite-api.service
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-poller
ExecStartPre=-/usr/bin/docker rm scalelite-poller
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-poller
ExecStart=/usr/bin/docker run --name scalelite-poller --env-file /etc/default/scalelite --network scalelite blindsidenetwks/scalelite:${SCALELITE_TAG}-poller
[Install]
WantedBy=scalelite.target
```

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

Create the systemd unit file `/etc/systemd/system/scalelite-recording-importer.service`

```
[Unit]
Description=Scalelite Recording Importer
After=network-online.target
Wants=network-online.target
Before=scalelite.target
PartOf=scalelite.target
After=scalelite-api.service
After=remote-fs.target
[Service]
EnvironmentFile=/etc/default/scalelite
ExecStartPre=-/usr/bin/docker kill scalelite-recording-importer
ExecStartPre=-/usr/bin/docker rm scalelite-recording-importer
ExecStartPre=/usr/bin/docker pull blindsidenetwks/scalelite:${SCALELITE_TAG}-recording-importer
ExecStart=/usr/bin/docker run --name scalelite-recording-importer --env-file /etc/default/scalelite --network scalelite --mount type=bind,source=${SCALELITE_RECORDING_DIR},target=/var/bigbluebutton blindsidenetwks/scalelite:${SCALELITE_TAG}-recording-importer
[Install]
WantedBy=scalelite.target
```

And enable it by running 
`systemctl enable scalelite-recording-importer.service`

You can now restart all scalelite services by running

`systemctl restart scalelite.target`

Afterwards, check the status with

`systemctl status scalelite-recording-importer.service`

to verify that the containers started correctly.

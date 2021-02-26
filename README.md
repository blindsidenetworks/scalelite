# Scalelite

[BigBlueButton](https://docs.bigbluebutton.org/) is an open source web conferencing system for online learning.

Scalelite is an open source load balancer that manages a pool of BigBlueButton servers.  It makes the pool of servers appear as a single (very scalable) BigBlueButton server.  A front-end, such as [Moodle](https://moodle.org/plugins/mod_bigbluebuttonbn) or [Greenlight](https://github.com/bigbluebutton/greenlight), sends standard BigBlueButton API requests to the Scalelite server which, in turn, distributes those request to the least loaded BigBlueButton server in the pool.

A single BigBlueButton server that meets the [minimum configuration](http://docs.bigbluebutton.org/2.2/install.html#minimum-server-requirements) supports around 200 concurrent users.

For many schools and organizations, the ability to 4 simultaneous classes of 50 users, or 8 simultaneous meetings of 25 users, is enough capacity.  However, what if a school wants to support 1,500 users across 50 simultaneous classes?  A single BigBlueButton server cannot handle such a load.

With Scalelite, a school can create a pool of 4 BigBlueButton servers and handle 16 simultaneous classes of 50 users.  Want to scale higher, add more BigBlueButton servers to the pool.

BigBlueButton has been in development for over 10 years now.  The latest release is a pure HTML5 client, with extensive documentation.  There is even a BigBlueButton install script called [bbb-install.sh](https://github.com/bigbluebutton/bbb-install) that lets you setup a BigBlueButton server (with a Let's Encrypt certificate) in about 15 minutes.  Using `bbb-install.sh` you can quickly setup a pool of servers for management by Scalelite.

To load balance the pool, Scalelite periodically polls each BigBlueButton to check if it is reachable online, ready to receive [API](http://docs.bigbluebutton.org/dev/api.html) requests, and to determine its current load (number of currently running meetings).  With this information, when Scalelite receives an incoming API call to [create](http://docs.bigbluebutton.org/dev/api.html#create) a new meeting, it places the new meeting on the least loaded server in the pool.   In this way, Scalelite can balance the load of meeting requests evenly across the pool.

Many BigBlueButton servers will create many recordings.  Scalelite can serve a large set of recordings by consolidating them together, indexing them in a database, and, when receiving an incoming [getRecordings](https://docs.bigbluebutton.org/dev/api.html#getrecordings), use the database index to return quickly the list of available recordings.

## Before you begin

The Scalelite installation process requires advanced technical knowledge.  You should, at a minimum, be very familar with
  
   * Setup and administration of a BigBlueButton server
   * Setup and administration of a Linux server and using common tools, such as `systemd`, to manage processes on the server
   * How the [BigBlueButton API](http://docs.bigbluebutton.org/dev/api.html) works with a front-end
   * How [docker](https://www.docker.com/) containers work 
   * How UDP and TCP/IP work together
   * How to administrate a Linux Firewall
   * How to setup a TURN server
   
If you are a beginner, you will have a difficult time getting any part of this deployment correct.  If you require help, see [Getting Help](#getting-help)

## Architecture of Scalelite

There are several components required to get Scalelite up and running:

1. Multiple BigBlueButton Servers
2. Scalelite LoadBalancer Server
3. NFS Shared Volume
4. PostgreSQL Database
5. Redis Cache 

An example Scalelite deployment will look like this:

![](images/scalelite.png)

### Minimum Server Requirements

For the Scalelite Server, the minimum recommended server requirements are:
- 4 CPU Cores
- 8 GB Memory

For **each** BigBlueButton server, the minimum requirements can be found [here](http://docs.bigbluebutton.org/2.2/install.html#minimum-server-requirements).
  
For the external Postgres Database, the minimum recommended server requirements are:
- 2 CPU Cores
- 2 GB Memory
- 20 GB Disk Space (should be good for tens of thousands of recordings)

For the external Redis Cache, the minimum recommended server requirements are:
- 2 CPU Cores
- 0.5GB Memory
- **Persistence must be enabled**

### Setup a pool of BigBlueButton Server

To setup a pool of BigBlueButton servers (minimum recommended number is 3), we recommend using [bbb-install.sh](https://github.com/bigbluebutton/bbb-install) as it can automate the steps to install, configure (with SSL + Let's Encrypt), and update the server when [new versions](https://github.com/bigbluebutton/bigbluebutton/releases) of BigBlueButton are released.

To help users who are behind restrictive firewalls to send/receive media (audio, video, and screen share) to your BigBlueButton server, you should setup a TURN server and configure each BigBlueButton server to use it.

Again, [bbb-install.sh](https://github.com/bigbluebutton/bbb-install#install-a-turn-server) can automate this process for you.

### Setup a shared volume for recordings

See [Setting up a shared volume for recordings](sharedvolume-README.md)

### Setup up a PostgreSQL Database

Setting up a PostgreSQL Database depends heavily on the infrastructure you use to setup Scalelite. We recommend you refer to your infrastructure provider's documentation.

Ensure the `DATABASE_URL` that you set in `/etc/default/scalelite` (in the [next step](docker-README.md#common-configuration-for-docker-host-system)) matches the connection url of your PostgreSQL Database. 

For more configuration options, see [configuration](#Configuration).

### Setup a Redis Cache

Setting up a Redis Cache depends heavily on the infrastructure you use to setup Scalelite. We recommend you refer to your infrastructure provider's documentation.

Ensure the `REDIS_URL` that you set in `/etc/default/scalelite` (in the [next step](docker-README.md#common-configuration-for-docker-host-system)) matches the connection url of your Redis Cache. 

For more configuration options, see [configuration](#Configuration).

### Deploying Scalelite Docker Containers

See [Deploying Scalelite Docker Containers](docker-README.md)

### Configure your Front-End to use Scalelite

To switch your Front-End application to use Scalelite instead of a single BigBlueButton server, there are 2 changes that need to be made

- `BigBlueButton server url` should be set to the url of your Scalelite deployment `http(s)://<scalelite-hostname>/bigbluebutton/api/`
- `BigBlueButton shared secret` should be set to the `LOADBALANCER_SECRET` value that you set in `/etc/default/scalelite`

## Configuration

### Environment Variables

#### Required

* `URL_HOST`: The hostname that the application API endpoint is accessible from. Used to protect against DNS rebinding attacks. Should be left blank if deploying Scalelite behind a Network Loadbalancer.
* `SECRET_KEY_BASE`: A secret used internally by Rails. Should be unique per deployment. Generate with `bundle exec rake secret` or `openssl rand -hex 64`.
* `LOADBALANCER_SECRET`: The shared secret that applications will use when calling BigBlueButton APIs on the load balancer. Generate with `openssl rand -hex 32`
* `LOADBALANCER_SECRETS`: Additional shared secrets, separated by `:`. Any of these secrets will work. In an environment where multiple applications need to integrate with a single scalelite server, it may be sensible to give each application its own secret. This way, revoking individual secrets later will not disturb other applications. 
* `DATABASE_URL`: URL for connecting to the PostgreSQL database, see the [Rails documentation](https://guides.rubyonrails.org/configuring.html#configuring-a-database). The URL should be in the form of `postgresql://username:password@connection_url`. Note that instead of using this environment variable, you can configure the database server in `config/database.yml`.
* `REDIS_URL`: URL for connecting to the Redis server, see the [Redis gem documentation](https://rubydoc.info/github/redis/redis-rb/master/Redis#initialize-instance_method). The URL should be in the form of `redis://username:password@connection_url`. Note that instead of using this environment variable, you can configure the redis server in `config/redis_store.yml` (see below). 

#### Docker-Specific

These variables are used by the service startup scripts in the Docker images, but are not used if you are deploying the application in a different way.

* `NGINX_SSL`: Set this variable to "true" to enable the "nginx" image to listen on SSL. If you enable this, then you must bind mount the files `/etc/nginx/ssl/live/$URL_HOST/fullchain.pem` and `/etc/nginx/ssl/live/$URL_HOST/privkey.pem` (containing the certificate plus intermediates and the private key respectively) into the Docker image. Alternately, you can mount the entire `/etc/letsencrypt` directory from certbot to `/etc/nginx/ssl` instead.
* `BEHIND_PROXY`: Set to true if scalelite is behind a proxy or load balancer.
* `POLL_INTERVAL`: Used by the "poller" image to set the interval at which BigBlueButton servers are polled, in seconds. Defaults to 60.
* `RECORDING_IMPORT_POLL`: Whether or not to poll the recording spool directory for new recordings. Defaults to "true". If the recording poll directory is on a local filesystem where inotify works, you can set this to "false" to reduce CPU overhead.
* `RECORDING_IMPORT_POLL_INTERVAL`: How often to check the recording spool directory for new recordings, in seconds (when running in poll mode). Defaults to 60.

#### Optional

* `PORT`: Set the TCP port number to listen on. Defaults to 3000.
* `BIND`: Instead of setting a port, you can set a URL to bind to. This allows using a Unix socket. See [The Puma documentation](https://puma.io/puma/Puma/DSL.html#bind-instance_method) for details.
* `INTERVAL`: Adjust the polling interval (in seconds) for updating server statistics and meeting status. Defaults to 60. Only used by the "poll" task.
* `WEB_CONCURRENCY`: The number of processes for the puma web server to fork. A reasonable value is 2 per CPU thread or 1 per 256MB ram, whichever is lower.
* `RAILS_MAX_THREADS`: The number of threads to run in the Rails process. The number of Redis connections in the pool defaults to match this value. The default is 5, a reasonable value for production.
* `RAILS_ENV`: Either `development`, `test`, or `production`. The Docker image defaults to `production`. Rails defaults to `development`.
* `BUILD_NUMBER`: An additional build version to report in the BigBlueButton top-level API endpoint. The Docker image has this preset to a value determined at image build time.
* `RAILS_LOG_TO_STDOUT`: Log to STDOUT instead of a file. Recommended for deployments with a service manager (e.g. systemd) or in Docker. The Docker image sets this by default.
* `REDIS_POOL`: Configure the Redis connection pool size. Defaults to `RAILS_MAX_THREADS`.
* `MAX_MEETING_DURATION`: The maximum length of any meeting created on any server. If the `duration` is passed as part of the create call, it will only be overwritten if it is greater than `MAX_MEETING_DURATION`.
* `RECORDING_SPOOL_DIR`: Directory where transferred recording files are placed. Defaults to `/var/bigbluebutton/spool`
* `RECORDING_WORK_DIR`: Directory where temporary files from recording transfer/import are extracted. Defaults to `/var/bigbluebutton/recording/scalelite`
* `RECORDING_PUBLISH_DIR`: Directory where published recording files are placed to make them available to the web server. Defaults to `/var/bigbluebutton/published`
* `RECORDING_UNPUBLISH_DIR`: Directory where unpublished recording files are placed to make them unavailable to the web server. Defaults to `/var/bigbluebutton/unpublished`
* `SERVER_HEALTHY_THRESHOLD`: The number of times an offline server needs to responds successfully for it to be considered online. Defaults to **1**. If you increase this number, you should decrease `POLL_INTERVAL`
* `SERVER_UNHEALTHY_THRESHOLD`: The number of times an online server needs to responds unsuccessfully for it to be considered offline. Defaults to **2**. If you increase this number, you should decrease `POLL_INTERVAL`
* `DB_DISABLED`: Disable the database by setting this value as `true`.
* `RECORDING_DISABLED`: Disable the recording feature and all its associated api's, by setting this value as `true`.
* `GET_MEETINGS_API_DISABLED`: Disable GET_MEETINGS API by setting this value as `true`.
* `POLLER_THREADS`: The number of threads to run in the poller process. The default is 5.
* `CONNECT_TIMEOUT`: The timeout for establishing a network connection to the BigBlueButton server in the load balancer and poller in seconds. Default is 5 seconds. Floating point numbers can be used for timeouts less than 1 second.
* `RESPONSE_TIMEOUT`: The timeout to wait for a response after sending a request to the BigBlueButton server in the load balancer and poller in seconds. Default is 10 seconds. Floating point numbers can be used for timeouts less than 1 second.
* `LOAD_MIN_USER_COUNT`: Minimum user count of a meeting, used for calculating server load. The default is 15.
* `LOAD_JOIN_BUFFER_TIME`: The time until the `LOAD_MIN_USER_COUNT` will be used for calculating server load. The default is 15.
* `LOAD_MIN_WEBCAM_COUNT` : The minimum number of active webcams, used for calculating server load. The default is 1.
* `LOAD_SCREENSHARE_COUNT` : Disable counting 1 screenshare for calculating server load by setting this value as `false`

### Redis Connection (`config/redis_store.yml`)

For a deployment using docker, you should configure the Redis Connection using the `REDIS_URL` environment variable instead, see above.

The `config/redis_store.yml` allows specifying per-environment configuration for the Redis server.
The file is similar in structure to the `config/database.yml` file used by ActiveRecord.
By default, a minimal configuration is shipped which will connect to a Redis server on localhost in development, and use "fakeredis" (an in-memory Redis emulator) to run tests without requiring a Redis server.
The default production configuration allows specifying the Redis server connection to use via an environment variable, see below.
You may use this configuration file to set any of the options listed in the [Redis initializer](https://rubydoc.info/github/redis/redis-rb/master/Redis#initialize-instance_method).
Additionally, these options can be set:

* `pool`: The number of connections in the pool (should match number of threads). Defaults to `RAILS_MAX_THREADS` environment variable, otherwise 5.
* `pool_timeout`: Amount of time (seconds) to wait if all connections in the pool are in use. Defaults to 5.
* `namespace`: An optional prefix to apply to all keys stored in Redis.

## Upgrading

Upgrading Scalelite to the latest version can be done using one command: 

`systemctl restart scalelite.target`

To confirm that you have the latest version, enter `http(s)://<scalelite-hostname>/bigbluebutton/api` in your browser and confirm that the value inside the `<build><\build>` tag is equal to the new version.

## Administration

Scalelite comes with a set of commands to

* Add/remove BigBlueButton servers from the pool
* Trigger an immediate poll of all BigBlueButton servers
* Change the state of any BigBlueButton server to being `available` and `unavailable` (don't try to put new meetings on the server)
* Monitor the load of all BigBlueButton servers

Server management is provided using rake tasks which update server information in Redis.

In a Docker deployment, these should be run from in the Docker container. You can enter the Docker container using a command like `docker exec -it scalelite-api /bin/sh`

### Show configured server details

```sh
./bin/rake servers
```

This will print a summary of details for each server which looks like this:

```
id: 2d2d674a-c6bb-48f3-8ad4-68f33a80a5b7
        url: https://bbb1.example.com/bigbluebutton/api
        secret: 2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535
        enabled
        load: 21.0
        load multiplier: 2.0
        online
```

Particular information to note:

* `id`: This is the ID value used when updating or removing the server
* `enabled` or `disabled`: Whether the server is administratively enabled. See "Enable/Disable servers" below.
* `load`: The number of meetings on the server. New meetings will be scheduled on servers with lower load. Updated by the poll process.
* `online`: Whether the server is responding to API requests. Updated by the poll process.

### Add a server

```sh
./bin/rake servers:add[url,secret,loadMultiplier]
```

The `url` value is the complete URL to the BigBlueButton API endpoint of the server. The `/api` on the end is required.
You can find the BigBlueButton server's URL and Secret by running `bbb-conf --secret` on the BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers. If not passed, it defaults to a value of `1`.

This command will print out the ID of the newly created server, and `OK` if it was successful.
Note that servers are added in the disabled state; see "Enable a server" below to enable it.

### Remove a server

```sh
./bin/rake servers:remove[id]
```

Warning: Do not remove a server which has running meetings! This will leave the database in an inconsistent state.
You should either wait for all meetings to end, or run the "Panic" function first.

### Disable a server

```sh
./bin/rake servers:disable[id]
```

Mark the server as disabled.
When a server is disabled, no new meetings will be started on the server.
Any existing meetings will continue to run until they finish.
The Poll process continues to run on disabled servers to update the "Online" status and detect ended meetings.
This is useful to "drain" a server for updates without disrupting any ongoing meetings.

### Enable a server

```sh
./bin/rake servers:enable[id]
```

Mark the server as enabled.

Note that the server won't be used for new meetings until after the next time the Poll process runs to update the load information.

### Panic a server

```sh
./bin/rake servers:panic[id]
```

Disable a server and clear all meeting state.
This method is used to recover from a crashed BigBlueButton server.
After the meeting state is cleared, anyone who tries to join a meeting that was previously on this server will instead be directed to a new meeting on a different server.

### Edit the load-multiplier of a server

```sh
./bin/rake servers:loadMultiplier[id,newLoadMultiplier]
```

Sets the load_multiplier for a BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers.

After changing the server needs to be polled at least once to see the new load.

### Poll all servers

```sh
./bin/rake poll:all
```

When you add a server to the pool, it may take upwards of 60 seconds (default value for `INTERVAL` for the background server polling process) before Scalelite marks the server as `online`.
You can run the above task to have it poll the server right away without waiting.

### Check the status of the entire deployment

```sh
./bin/rake status
```

This will print a table displaying a list of all servers and some basic statistics that can be used for monitoring the overall status of the deployment

```
     HOSTNAME        STATE   STATUS  MEETINGS  USERS  LARGEST MEETING  VIDEOS
 bbb1.example.com  enabled   online        12     25                7      15
 bbb2.example.com  enabled   online         4     14                4       5
```


## Getting Help

For commercial help with setup and deployment of Scalelite, contact us at [Blindside Networks](https://blindsidenetworks.com/scaling-bigbluebutton/).

## Trademarks

This project uses BigBlueButton and is not endorsed or certified by BigBlueButton Inc.  BigBlueButton and the BigBlueButton Logo are trademarks of [BigBlueButton Inc](https://bigbluebutton/org).

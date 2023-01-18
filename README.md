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
* `LOADBALANCER_SECRETS`: Additional shared secrets, separated by `:`. Any of these secrets will work. In an environment where multiple applications need to integrate with a single scalelite server, it may be sensible to give each application its own secret. This way, revoking individual secrets later will not disturb other applications. For working of events like `analytics-callback`, the bbb-server's secrets should be added here.
* `LOADBALANCER_CHECKSUM_ALGORITHM`: Define a list of the algorithms allowed to calculate the checksum e.g. [SHA1:SHA256:SHA512], [SHA1:SHA256] or [SHA512]. The same algorithm in the request is transferred to requests made to BigBlueButton. When not set, Scalelite accepts checksums generated with SHA1, SHA256, or SHA512 and calls to BigBlueButton servers use SHA256.
* `DATABASE_URL`: URL for connecting to the PostgreSQL database, see the [Rails documentation](https://guides.rubyonrails.org/configuring.html#configuring-a-database). The URL should be in the form of `postgresql://username:password@connection_url`. Note that instead of using this environment variable, you can configure the database server in `config/database.yml`.
* `REDIS_URL`: URL for connecting to the Redis server, see the [Redis gem documentation](https://rubydoc.info/github/redis/redis-rb/master/Redis#initialize-instance_method). The URL should be in the form of `redis://username:password@connection_url`. Note that instead of using this environment variable, you can configure the redis server in `config/redis_store.yml` (see below).

#### Docker-Specific

These variables are used by the service startup scripts in the Docker images, but are not used if you are deploying the application in a different way.

* `NGINX_SSL`: Set this variable to "true" to enable the "nginx" image to listen on SSL. If you enable this, then you must bind mount the files `/etc/nginx/ssl/live/$URL_HOST/fullchain.pem` and `/etc/nginx/ssl/live/$URL_HOST/privkey.pem` (containing the certificate plus intermediates and the private key respectively) into the Docker image. Alternately, you can mount the entire `/etc/letsencrypt` directory from certbot to `/etc/nginx/ssl` instead.
* `NGINX_BEHIND_PROXY`: Set to true if scalelite is behind a proxy or load balancer.
* `NGINX_RECORDINGS_ONLY`: Set to true if scalelite-nginx will be used for proxying recordings only.
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
* `RAILS_LOG_LEVEL`: Set log level of production environment (debug, info, warn, error, fatal, unknown). Default is `debug`.
* `REDIS_POOL`: Configure the Redis connection pool size. Defaults to `RAILS_MAX_THREADS`.
* `MAX_MEETING_DURATION`: The maximum length of any meeting created on any server in minutes. If the `duration` is passed as part of the create call, it will only be overwritten if it is greater than `MAX_MEETING_DURATION`.
* `RECORDING_SPOOL_DIR`: Directory where transferred recording files are placed. Defaults to `/var/bigbluebutton/spool`
* `RECORDING_WORK_DIR`: Directory where temporary files from recording transfer/import are extracted. Defaults to `/var/bigbluebutton/recording/scalelite`
* `RECORDING_PUBLISH_DIR`: Directory where published recording files are placed to make them available to the web server. Defaults to `/var/bigbluebutton/published`
* `RECORDING_UNPUBLISH_DIR`: Directory where unpublished recording files are placed to make them unavailable to the web server. Defaults to `/var/bigbluebutton/unpublished`
* `SERVER_HEALTHY_THRESHOLD`: The number of times an offline server needs to responds successfully for it to be considered online. Defaults to **1**. If you increase this number, you should decrease `POLL_INTERVAL`
* `SERVER_UNHEALTHY_THRESHOLD`: The number of times an online server needs to responds unsuccessfully for it to be considered offline. Defaults to **2**. If you increase this number, you should decrease `POLL_INTERVAL`
* `DB_DISABLED`: Disable the database by setting this value as `true`.
* `RECORDING_DISABLED`: Disable the recording feature and all its associated api's, by setting this value as `true`.
* `RECORDING_IMPORT_UNPUBLISHED`: Imported recordings can be marked as unpublished by default, by setting this value as `true`. Defaults to `false`.
* `GET_MEETINGS_API_DISABLED`: Disable GET_MEETINGS API by setting this value as `true`.
* `POLLER_THREADS`: The number of threads to run in the poller process. The default is 5. The poller threads should be increased carefully, since higher poller threads can lead to Denial Of Service problems at DNS.
* `CONNECT_TIMEOUT`: The timeout for establishing a network connection to the BigBlueButton server in the load balancer and poller in seconds. Default is 5 seconds. Floating point numbers can be used for timeouts less than 1 second.
* `POLLER_WAIT_TIMEOUT`: The timeout value set for the poller to finish polling a server. Defaults to 10.
* `RESPONSE_TIMEOUT`: The timeout to wait for a response after sending a request to the BigBlueButton server in the load balancer and poller in seconds. Default is 10 seconds. Floating point numbers can be used for timeouts less than 1 second.
* `LOAD_MIN_USER_COUNT`: Minimum user count of a meeting, used for calculating server load. Defaults to 15.
* `LOAD_JOIN_BUFFER_TIME`: The time(in minutes) until the `LOAD_MIN_USER_COUNT` will be used for calculating server load. Defaults to 15.
* `SERVER_ID_IS_HOSTNAME`: If set to "true", then instead of generating random UUIDs as the server ID when adding a server Scalelite will use the hostname of the server as the id. Server hostnames will be checked for uniqueness. Defaults to "false".
* `CREATE_EXCLUDE_PARAMS`: List of BBB server attributes that should not be modified by create API call. Should be in the format 'CREATE_EXCLUDE_PARAMS=param1,param2,param3'.
* `JOIN_EXCLUDE_PARAMS`: List of BBB server attributes that should not be modified by join API call. Should be in the format 'JOIN_EXCLUDE_PARAMS=param1,param2,param3'.
* `DEFAULT_CREATE_PARAMS`: Sets a list of default params on the create call that CAN be overridden by the client/requester. Should be in the format 'DEFAULT_CREATE_PARAMS=param1=param1value,param2=param2value'
* `OVERRIDE_CREATE_PARAMS`: Sets a list of params on the create call that CANNOT be overridden by the client/requester. Should be in the format 'OVERRIDE_CREATE_PARAMS=param1=param1value,param2=param2value'
* `DEFAULT_JOIN_PARAMS`: Sets a list of default params on the join call that CAN be overridden by the client/requester. Should be in the format 'DEFAULT_JOIN_PARAMS=param1=param1value,param2=param2value'
* `OVERRIDE_JOIN_PARAMS`: Sets a list of  params on the create call that CANNOT be overridden by the client/requester. Should be in the format 'OVERRIDE_JOIN_PARAMS=param1=param1value,param2=param2value'
* `GET_RECORDINGS_API_FILTERED`: Prevent get_recordings api from returning all recordings when recordID is not specified in the request, by setting value to 'true'. Defaults to false.
* `PREPARED_STATEMENT`: Enable/Disable Active Record prepared statements feature, can be disabled by setting the value as `false`. Defaults to `true`.
* `DB_CONNECTION_RETRY_COUNT`: The number of times db connection retries will be attempted, in case of a db connection failure. Defaults to `3`.
* `RECORDING_PLAYBACK_FORMATS`: Recording playback formats supported by Scalelite, defaults to `presentation:video:podcast:notes:capture`.
* `PROTECTED_RECORDINGS_ENABLED`: Applies to the recording import process. If set to "true", then newly imported recordings will have protected links enabled. Default is "false".
* `PROTECTED_RECORDINGS_TOKEN_TIMEOUT`: Protected recording link token timeout in minutes. This is the amount of time that the one-time-use link returned in `getRecordings` calls will be valid for. Defaults to 60 minutes (1 hour).
* `PROTECTED_RECORDINGS_TIMEOUT`: Protected recordings resource access cookie timeout in minutes. This is the amount of time that a user will be granted access to view a recording for after clicking on the one-time-use link. Defaults to 360 minutes (6 hours).
* `SCALELITE_API_PORT`: Runs the SCALELITE_API in custom port number. Defaults to 3000.
* `DEFAULT_LOCALE`: Change the language that user facing pages displays in (currently supports `en`)
* `VOICE_BRIDGE_LEN`: The length (number of digits) of voice bridge numbers generated by Scalelite. Defaults to `7`. Shorter voice bridge numbers are easier to enter, but also easier to guess through random tries. Your BigBlueButton config must support the selected length.
* `USE_EXTERNAL_VOICE_BRIDGE`: Whether or not to try to use the `voiceBridge` number passed by the BigBlueButton API client. Defaults to `false`. If your API client generates numbers compatible with your BigBlueButton configuration, you can change this to `true` to use them. Note that Scalelite will ignore the voice bridge number provided, and generate a new one, if the number is already in use by a different meeting.
* `FSAPI_PASSWORD`: Password (for "Basic" authentication) to access the freeswitch dialplan API. Default is to use the first `LOADBALANCER_SECRET` as the password. You can set this to the empty string to disable authentication.
* `FSAPI_MAX_DURATION`: Maximum duration for voice calls handled by the freeswitch dialplan integration in minutes. Defaults to `MAX_MEETING_DURATION` if that is set, otherwise no limit. You probably want to set a limit here to ensure you do not have excess expenses due to people not hanging up calls.

### Multitenancy
Scalelite supports multitenancy by way of using subdomains. For example, if you have two tenants, t1 and t2, setup DNS entries t1.example.com and t2.example.com pointing your scalelite server (sl.example.com). Update the scalelite-api docker container with the following environmental variables:
MULTITENANCY_ENABLED : true to enable multitenancy; defaults to false when variable is absent
BASE_URL : base domain.  example.com in our example
Register the tenants using:
```sh
docker exec -it scalelite-api /bin/bash
bin/rake tenants:add[t1,secret1]
bin/rake tenants:add[t2,secret2]
bin/rake tenants:showall #confirm tenants
```
In your LMS BigBlueButton module configuration settings, update the url and secret fields:
`https://sl.example.com/bigbluebutton/api => https://t1.example.com/bigbluebutton/api`
`secret => secret1`
#### Add Tenant
`bin/rake tenants:add[id,secrets]`
Add multiple secret if required by providing a comma separated list.
#### Remove Tenant
`bin/rake tenants:remove[id]`
#### Update Tenant
`bin/rake tenants:update[id,id2,secrets] #change from subdomain id1 to id2`
#### Show Tenants
`bin/rake tenants:showall`


### Customizing Strings

If you'd like to customize the strings on certain error pages returned by Scalelite (`recording_not_found`), you can do so by duplicating the locale file and changing whatever lines you see fit.

Create the directory `/etc/default/scalelite-locales` and copy over the contents of the locales folder that can be found [here](https://github.com/blindsidenetworks/scalelite/tree/master/config/locales).

Choose the locale that you want to edit replace any string with whatever text you want. Note that you will need to manually update this file if any new strings are added in a release. 

Edit `/etc/default/scalelite` and add the following line
```
SCALELITE_API_EXTRA_OPTS=--mount type=bind,source=/etc/default/scalelite-locales,target=/srv/scalelite/config/locales
```
Now restart all scalelite services by running `systemctl restart scalelite.target`

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

note: If the `SCALELITE_TAG` is set to v1, the latest release in v1 series will be taken. You can also choose the specific version by specifying the version number as`SCALELITE_TAG=v1.1.7`, which would be the recommended way. All the details regarding each versions can be found at `https://github.com/blindsidenetworks/scalelite/releases`. Some versions might require setting certain environment variables or migrations to be run.

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

Make sure that there is no space between the parameters [url,secret,loadMultipler] and the comma as it causes a "rake aborted!" error.

### Remove a server

```sh
./bin/rake servers:remove[id]
```

Warning: Do not remove a server which has running meetings! This will leave the database in an inconsistent state.
You should either wait for all meetings to end, or run the "Panic" function first.

### Update a server

```sh
./bin/rake servers:update[id,secret,loadMultiplier]
```

Updates the secret and load_multiplier for a BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers.

After changing the server needs to be polled at least once to see the new load.

### Disable a server

```sh
./bin/rake servers:disable[id]
```

Mark the server as disabled.
When a server is disabled, no new meetings will be started on the server.
You will not be able to join existing meetings.
The Poll process does not update disabled servers.
You should not disable a server if it has active load, you can either use the cordon option to drain the server or respond with `yes` to clear all meeting state.

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

### Cordon a server

```sh
./bin/rake servers:cordon[id]
```

Mark the server as cordoned.
When a server is cordoned, no new meetings will be started on the server.
Any existing meetings will continue to run until they finish.
The Poll process continues to run on cordoned servers to update the "Online" status and detect ended meetings.
The get_meetings API would also return all the active meetings in the cordoned server.
This is useful to "drain" a server for updates without disrupting any ongoing meetings.
The server state will be updated to `disabled` by the poller once the load in server becomes zero or nil.

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

### List all meetingIds running in given servers

To list meetings in a specific servers, the following command can be used

```sh
./bin/rake servers:meeting_list["serverID1:serverID2:serverID3"]
```
To list all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake servers:meeting_list
```

### Add multiple servers through a config file

```sh
./bin/rake servers:addAll[file]
```

**Deprecated:** See `servers:sync` for a more flexible alternative.

Adds all the servers defined in a YAML file passed as an argument. The file passed in should have the following format:

```yaml
servers:
  - url: "bbb1.example.com"
    secret: "1bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
  - url: "bbb2.example.com"
    secret: "2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
  - url: "bbb3.example.com"
    secret: "3bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
```

The command will print out each added server's `url` and `id` once it has been successfully added.
Note that all servers are added in the disabled state; see "Enable a server" above to enable them.

### Configure all servers from a single YAML configuration file

```sh
./bin/rake servers:sync[path,mode,dryrun]
```

Add, remove or modify servers according to a YAML configuration file.

The `path` parameter should point to a valid YAML configuration file as described
below. Pass `-` as the path to read configuration from standard input instead.
You can use the `servers:yaml` task to bootstrap a valid configuration file from
an existing scalelite cluster.

The `mode` parameter controls how unwanted servers are removed. `mode=keep` will
not remove any servers. `mode=cordon` (the default) will remove empty servers
and cordon non-empty servers. You may have to repeat the task once these servers
are empty to actually remove them. `mode=force` will try to end all meetings on
unwanted servers and then remove them. This works similar to `servers:panic[id]`.

If `dryrun` is true, the task will run normally but not persist any changes or
end any meetings. This can be used to simulate a sync and see what would happen.

The configuration file should contain a complete list of all servers and follow
this structure:

```yaml
servers:
    <server-id>:                 # must be unique, should be a hostname
        secret: <string>         # required
        url: <string>            # default: "https://<server-id>/bigbluebutton/api"
        enabled: <bool>          # default: true
        load_multiplier: <float> # default: 1.0, must be greater than 0

    # Example for a simple server with default values
    bbb1.example.com:
        secret: "1bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"

    # Full example for a legacy server (generated id)
    02bff3a7-c95f-49d3-b1e5-c53eddd4dd68:
        secret: "2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
        url: "https://bbb2.example.com/bigbluebutton/api"
        enabled: false
        load_multiplier: 5.0
```

The task will try to reach the desired cluster state by adding, removing or
modifying servers as needed. To be more exact, the task will:

1. Read the configuration file and perform some basic sanity checks.
2. Add missing servers, based on server IDs.
3. Update configuration for existing servers (`secret`, `url` and `load_multiplier`).
4. Cordon servers that are enabled but should be disabled.
5. Enable servers that are disabled or cordoned but should be enabled.
6. Try to remove servers that are no present in the YAML configuration.
    * In `keep` mode, no servers are removed.
    * In `cordon` mode (default), only empty servers are removed. Non-empty servers are cordoned.
    * In `force` mode, servers are forcefully evicted and then removed.


### Export current server list as YAML

```sh
./bin/rake servers:yaml[verbose]
```

Prints a YAML file compatible with `servers:sync`. This task can be used to
bootstrap a cluster configuration file from an existing cluster, or get the
current cluster state in a mashine-readable format. If `verbose` is true, then
additional fields (`state`, `load` and `online`) are included. These are ignored
by `servers:sync`.


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

### Manage Meetings

#### List all/specific meetings running in BigBlueButton servers

To list specific meetings, use:

```sh
./bin/rake meetings:list["meetingId1:meetingId2:meetingId3"]
```

To list all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake meetings:list
```

#### End all/specific meetings running in BigBlueButton servers

To End specific meetings, use:

```sh
./bin/rake meetings:end["meetingId1:meetingId2:meetingId3"]
```

To End all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake meetings:end
```

#### Get meeting details of a meeting running in BigBlueButton server

```sh
./bin/rake meetings:info[meetingId]
```

This command will return the following meeting details of a meeting:

```
Meeting ID: 1a813084f7af08b8d19239315c170b3decedfc03-2-1
	Meeting Name: new class
	Internal MeetingID: 4445471c7ae2987ddb11db3fa2d89f8c8f86c328-1633448534301
	Created Date: Tue Oct 05 15:42:14 UTC 2021
	Recording Enabled: true
	Server id: bbb.example.com
	Serevr url: https://bbb.example.com/bigbluebutton/api/
	MetaData:
		bbb-context-name: test124
		analytics-callback-url: https://bbb1.example.com/bigbluebutton/api/analytics_callback
		bbb-recording-tags: 
		bbb-origin-server-common-name: 
		bbb-context-label: test
		bbb-origin: test
		bbb-context: test
		bbb-context-id: 2
		bbb-recording-name: new class
		bbb-origin-server-name: xx.xx.xxx.xx
		bbb-recording-description: 
		bbb-origin-tag: moodle-mod_bigbluebuttonbn
```

## Getting Help

For commercial help with setup and deployment of Scalelite, contact us at [Blindside Networks](https://blindsidenetworks.com/contact).

## Trademarks

This project uses BigBlueButton and is not endorsed or certified by BigBlueButton Inc.  BigBlueButton and the BigBlueButton Logo are trademarks of [BigBlueButton Inc](https://bigbluebutton.org).

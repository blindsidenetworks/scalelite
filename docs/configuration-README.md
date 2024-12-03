## Configuration

### Environment Variables

#### Required

* `URL_HOST`: The hostname that the application API endpoint is accessible from. Used to protect against DNS rebinding attacks. Should be left blank if deploying Scalelite behind a Network Loadbalancer.
* `SECRET_KEY_BASE`: A secret used internally by Rails. Should be unique per deployment. Generate with `bundle exec rake secret` or `openssl rand -hex 64`.
* `LOADBALANCER_SECRET`: The shared secret that applications will use when calling BigBlueButton APIs on the load balancer. Generate with `openssl rand -hex 32`
* `LOADBALANCER_SECRETS`: Additional shared secrets, separated by `:`. Any of these secrets will work. In an environment where multiple applications need to integrate with a single scalelite server, it may be sensible to give each application its own secret. This way, revoking individual secrets later will not disturb other applications. For working of events like `analytics-callback`, the bbb-server's secrets should be added here.
* `LOADBALANCER_CHECKSUM_ALGORITHM`: Define a list of the algorithms allowed to calculate the checksum e.g. `SHA1:SHA256:SHA512`, `SHA1:SHA256` or `SHA512`. If set, Scalelite accepts checksums generated with the specified algorithms and makes calls to BigBlueButton servers using the specified algorithm with the highest security (SHA512 -> SHA256 -> SHA1). When not set, Scalelite accepts checksums generated with SHA1, SHA256, or SHA512 and calls to BigBlueButton servers use SHA256.
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
* `RAILS_MAX_THREADS`: The number of threads to run in the Rails process. The number of Redis connections in the pool defaults to match this value. The default is 3, a reasonable value for production.
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

### Configure your Front-End to use Scalelite

To switch your Front-End application to use Scalelite instead of a single BigBlueButton server, there are 2 changes that need to be made

- `BigBlueButton server url` should be set to the url of your Scalelite deployment `http(s)://<scalelite-hostname>/bigbluebutton/api/`
- `BigBlueButton shared secret` should be set to the `LOADBALANCER_SECRET` value that you set in `/etc/default/scalelite`

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

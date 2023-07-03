# Scalelite

[BigBlueButton](https://docs.bigbluebutton.org/) is an open source web conferencing system for online learning.

Scalelite is an open source load balancer that manages a pool of BigBlueButton servers.  It makes the pool of servers appear as a single (very scalable) BigBlueButton server.  A front-end, such as [Moodle](https://moodle.org/plugins/mod_bigbluebuttonbn) or [Greenlight](https://github.com/bigbluebutton/greenlight), sends standard BigBlueButton API requests to the Scalelite server which, in turn, distributes those request to the least loaded BigBlueButton server in the pool.

A single BigBlueButton server that meets the [minimum configuration](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements) supports around 200 concurrent users.

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
- Latest version of Docker (ScaleLite will no run on docker 19.x)

For **each** BigBlueButton server, the minimum requirements can be found [here](https://docs.bigbluebutton.org/administration/install#minimum-server-requirements).

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

See [Setting up a shared volume for recordings](docs/sharedvolume-README.md)

### Setup up a PostgreSQL Database

Setting up a PostgreSQL Database depends heavily on the infrastructure you use to setup Scalelite. We recommend you refer to your infrastructure provider's documentation.

Ensure the `DATABASE_URL` that you set in `/etc/default/scalelite` (in the [next step](docs/docker-README.md#common-configuration-for-docker-host-system)) matches the connection url of your PostgreSQL Database.

For more configuration options, see [configuration](docs/configuration-README.md#Configuration).

### Setup a Redis Cache

Setting up a Redis Cache depends heavily on the infrastructure you use to setup Scalelite. We recommend you refer to your infrastructure provider's documentation.

Ensure the `REDIS_URL` that you set in `/etc/default/scalelite` (in the [next step](docs/docker-README.md#common-configuration-for-docker-host-system)) matches the connection url of your Redis Cache.

For more configuration options, see [configuration](docs/configuration-README.md#Configuration).

### Deploying Scalelite Docker Containers

See [Deploying Scalelite Docker Containers](docs/docker-README.md)

## Upgrading

Upgrading Scalelite to the latest version can be done using one command:

`systemctl restart scalelite.target`

note: If the `SCALELITE_TAG` is set to v1, the latest release in v1 series will be taken. You can also choose the specific version by specifying the version number as`SCALELITE_TAG=v1.1.7`, which would be the recommended way. All the details regarding each versions can be found at `https://github.com/blindsidenetworks/scalelite/releases`. Some versions might require setting certain environment variables or migrations to be run.

To confirm that you have the latest version, enter `http(s)://<scalelite-hostname>/bigbluebutton/api` in your browser and confirm that the value inside the `<build><\build>` tag is equal to the new version.

## Configuration

For the configuration options, see [configuration](docs/configuration-README.md#Configuration).

## Management - Rake Tasks

For the administrative rake tasks, see [rake tasks](docs/rake-README.md)

## Management - API

For the administrative api, see [api](docs/api-README.md)

## Getting Help

For commercial help with setup and deployment of Scalelite, contact us at [Blindside Networks](https://blindsidenetworks.com/contact).

## Trademarks

This project uses BigBlueButton and is not endorsed or certified by BigBlueButton Inc.  BigBlueButton and the BigBlueButton Logo are trademarks of [BigBlueButton Inc](https://bigbluebutton.org).


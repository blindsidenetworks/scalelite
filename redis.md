# Redis data structure

## Servers

### Server Information Hash

For each server, there is a Redis hash with the key `server:{ID}`.
This hash contains the following keys:

* `url`: The URL endpoint for making BigBlueButton API calls on this server
* `secret`: The shared secret for signing BigBlueButton API calls on this server
* `online`: The last online/offline result from the server health check

### Servers Set

This is a single set with the key `servers`
It contains the ID field for each server that the load balancer knows about.

### Servers Enabled Set

This is a single set with the key `server_enabled`.
It contains the ID field for each server which is administratively enabled (allowed to be used for new meetings).

### Servers Load Sorted Set

There is a single sorted set with the key `server_load`.
This set contains an entry for each BigBlueButton server.
For each server, the value stored in this set is the server ID.
The score attached corresponds to the load on the server (number of meetings).
Lower scores mean a server has less load.

If a server is present in this set, that means it is available to be used for creating new meetings on.
(The server is enabled and online)
Every server in this set MUST also be in the `server_enabled` set.

## Meetings

### Meeting Information Hash

For each meeting, there is a Redis hash with the key `meeting:{ID}`.
The ID is the `meetingID=` parameter as passed on the `create` API call.
This hash contains the following keys:

* `server_id`: The ID of the server that the meeting is allocated on.

### Meetings Set

This is a single set with the key `meetings`.
It contains the ID field for each meeting that the load balancer knows about.

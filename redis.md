# Redis data structure

## Servers

### Server Information Hash

For each server, there is a Redis hash with the key `server:{ID}`.
This hash contains the following keys:

* `url`: The URL endpoint for making BigBlueButton API calls on this server
* `secret`: The shared secret for signing BigBlueButton API calls on this server

### Servers Load Sorted Set

There is a single sorted set with the key `server_load`.
This set contains an entry for each BigBlueButton server.
For each server, the value stored in this set is the server ID.
The score attached corresponds to the load on the server (number of meetings).
Lower scores mean a server has less load.

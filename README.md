# scalelite-api

Sidecar application for [scalelite](https://github.com/blindsidenetworks/scalelite) load balancer acting as RESTful API.

You will need to specify the following environmental variables

- APP_SECRET - application secret used for API calls
- REDIS_URL - URL of the redis used with scalelite 


The following endpoints are available:

| Endpoint                        | Description                                  | Required Parameters      | Optional Parameters - |
| ------------------------------- | -------------------------------------------- | ------------------------ | --------------------- |
| scalelite/api                   | generic liveness probe endpoint              | -                        | -                     |
| scalelite/api/getServers        | get all servers in the pool                  | -                        | -                     |
| scalelite/api/getServerInfo     | get info about particular server in the pool | serverID                 | -                     |
| scalelite/api/addServer         | add server in the pool                       | serverURL, serverSecret  | loadMultiplier        |
| scalelite/api/removeServer      | remove server from the pool                  | serverID                 | -                     |
| scalelite/api/enableServer      | enable a server                              | serverID                 | -                     |
| scalelite/api/disableServer     | disable a server                             | serverID                 | -                     |
| scalelite/api/setLoadMultiplier | set load multiplier for a server             | serverID, loadMultiplier | -                     |

The endpoints are protected using [the same checksum scheme](https://docs.bigbluebutton.org/dev/api.html#api-calls) as BBB API. 


### Credits

This application started as a fork of scalelite. Cheers to scalelite developers.
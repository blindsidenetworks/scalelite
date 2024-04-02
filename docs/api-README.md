# Scalelite Management Using APIs

Scalelite comes with an API that allows for the management of tenants and servers.

## Servers API

### All Servers
```sh 
GET /scalelite/api/getServers
```

Returns a list of all servers

#### Expected Parameters
n/a

#### Successful Response

```
[
  {
   "id": String,
   "url": String,
   "secret": String,
   "tag": String,
   "state": String,
   "load": String,
   "load_multiplier": String,
   "online": String
  },
  ...
],
status: ok
```

#### Example cURL

```bash
curl --request GET 'https://scalelite-hostname.com/scalelite/api/getServers?checksum=<checksum>'
```

### Show Server
```sh 
GET /scalelite/api/getServerInfo?id=
```

Returns the data associated with a single server

#### Expected Parameters
```
`id` the id of the server
```

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "tag": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

 ```bash
 curl --header "Content-Type: application/json" --request GET 'https://scalelite-hostname.com/scalelite/api/getServerInfo?id=<id>&checksum=<checksum>'
 ```

### Create Server
```sh 
POST /scalelite/api/addServer
```

Adds a new server

#### Expected Parameters
```
{
  "server": {
    "url": String,                 # Required: URL of the BigBlueButton server
    "secret": String,              # Required: Secret key of the BigBlueButton server
    "load_multiplier": Float,      # Optional: A non-zero number, defaults to 1.0 if not provided or zero
    "tag": String                  # Optional: A special-purpose tag for the server (empty string to not set it)
  }
}
```

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "tag": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"server": {"url": "https://server1.com/bigbluebutton/api", "secret":"example-secret" } }' 'https://scalelite-hostname.com/scalelite/api/addServer?checksum=<checksum>' -v
```

### Update Server
```sh 
POST /scalelite/api/updateServer
```

Updates a server

#### Expected Parameters
```
{
  "id" : String              # Required
  "server": {
    "state": String,         # Optional: 'enable', 'cordon', or 'disable'
    "load_multiplier": Float # Optional: A non-zero number
    "secret": String,        # Optional: Secret key of the BigBlueButton server
    "tag": String            # Optional: A special-purpose tag for the server (empty string to remove the tag)
  }
}
```

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "tag": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"id": "<server-id>", "server": {"secret":"new-secret"} }' 'https://scalelite-hostname.com/scalelite/api/updateServer?checksum=<checksum>' -v
```

### Delete Server
```sh 
POST /scalelite/api/deleteServer
```

Deletes a server

#### Expected Parameters
```
{ 
  "id" : String   # Required
}
```

#### Successful Response
```
{
  success: {
    "Server id=<:id> was destroyed"
  }
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" -request POST --data '{"id":"<server-id>"}' 'https://scalelite-hostname.com/scalelite/api/deleteServer?checksum=<checksum>' -v
```

### Panic
```sh
POST /scalelite/api/panicServer
```

Set a server as unavailable and destroy all meetings from it

#### Expected Parameters
```
{
  "id": String            # Required
  "server": {
    "keep_state": Boolean # Optional: Set to 'true' if you want to keep the server's state after panicking, defaults to 'false'
  }
}
```

#### Successful Response
```
{
  success: {
    "Server id=<:id> has been disabled and the meetings have been destroyed"
  }
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"id":"<server-id>"}' 'https://scalelite-hostname.com/scalelite/api/panicServer?checksum=<checksum>' -v
```

## Tenants API

### All Tenants
```sh 
GET /scalelite/api/getTenants
```

Returns a list of all tenants

#### Expected Parameters
n/a

#### Successful Response

```
[
  {
    "id": String,
    "name": String,
    "secrets": String,
  },
  ...
],
status: ok
```

#### Example cURL

```bash
curl --request GET 'https://scalelite-hostname.com/scalelite/api/getTenants?checksum=<checksum>'
```

### Show Tenant
```sh 
GET /scalelite/api/getTenantInfo?id=<tenant-id>
```

Returns the data associated with a single tenant

#### Expected Parameters
`id` the id of the tenant for which you are searching for.

#### Successful Response
```
{
  "id": String,
  "name": String,
  "secrets": String,
  "destroyed": Boolean,
  "new_record": Boolean
},
status: ok
```

#### Example cURL

 ```bash
 curl --request GET 'https://scalelite-hostname.com/scalelite/api/getTenantInfo?id=<tenant-id>&checksum=<checksum>'
 ```

### Create Tenant
```sh 
POST /scalelite/api/addTenant
```

#### Expected Parameters

```
{
  "tenant": {
    "name": String,                 # Required: Name of the tenant
    "secrets": String,              # Required: Tenant secret(s)
  }
}
```
#### Successful Response
```
{
  "id": String
}, 
status: created
``` 

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"tenant": {"name": "example-tenant", "secrets":"example-secret" } }' 'https://scalelite-hostname.com/scalelite/api/addTenant?id=<tenant-id>&checksum=<checksum>' -v
```

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

### Update Tenant
```sh
POST /scalelite/api/updateTenant
```


#### Expected Parameters

```
{
  "tenant": {
    "name": String,     # include the parameter you want updated
    "secrets": String
  }
}
```

#### Successful Response

```
{
  "id": String,
  "name": String,
  "secrets": String,
  "destroyed": Boolean,
  "new_record": Boolean
}
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"id":"<tenant-id>", "tenant": {"secrets":"new-secret" } }' 'https://scalelite-hostname.com/scalelite/api/updateTenant?id=<tenant-id>&checksum=<checksum>'-v
```

### Remove Tenant
```sh
POST /scalelite/api/deleteTenant
```

#### Expected Parameters
`id` the id of the tenant you wish to delete

#### Successful Response

```
{ 
  "id": String 
}
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST  --data '{"id":"<tenant-id>"}' 'https://scalelite-hostname.com/scalelite/api/deleteTenant?id=<tenant-id>&checksum=<checksum>'
```

Warning: Removing a tenant with data still in the database may cause some inconsistencies.

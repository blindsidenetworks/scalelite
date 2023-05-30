# Scalelite Management Using APIs

Scalelite comes with an API that allows for the management of tenants and servers.

## Servers API

### All Servers
```sh 
GET /api/servers
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
curl --request GET https://scalelite-hostname.com/api/servers
```

### Show Server
```sh 
GET /api/servers/:id
```

Returns the data associated with a single server

#### Expected Parameters
n/a

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

 ```bash
 curl --request GET https://scalelite-hostname.com/api/servers/<id>
 ```

### Create Server
```sh 
POST /api/servers
```

Adds a new server

#### Expected Parameters
```
{
  "server": {
    "url": String,                 # Required: URL of the BigBlueButton server
    "secret": String,              # Required: Secret key of the BigBlueButton server
    "load_multiplier": Float       # Optional: A non-zero number, defaults to 1.0 if not provided or zero
  }
}
```

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request POST --data '{"url": "https://server1.com/bigbluebutton/api", "secret":"example-secret" }' https://scalelite-hostname.com/api/servers -v
```

### Update Server
```sh 
PUT /api/servers/:id
```

Updates a server

#### Expected Parameters
```
{
  "server": {
    "state": String,         # Optional: 'enable', 'cordon', or 'disable'
    "load_multiplier": Float # Optional: A non-zero number
    "secret": String         # Optional: Secret key of the BigBlueButton server
  }
}
```

#### Successful Response
```
{
  "id": String,
  "url": String,
  "secret": String,
  "state": String,
  "load": String,
  "load_multiplier": String,
  "online": String
},
status: ok
```

#### Example cURL

```bash
curl --header "Content-Type: application/json" --request PATCH --data '{"secret":"new-secret" }' https://scalelite-hostname.com/api/server/<server-id> -v
```

### Delete Server
```sh 
DELETE /api/servers/:id
```

Deletes a server

#### Expected Parameters
n/a

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
curl --header "Content-Type: application/json" --request DELETE https://scalelite-hostname.com/api/servers/a783d62f-e457-4842-b23b-28a34d3a219e -v
```

### Panic
```sh
POST /api/servers/:id/panic
```

Set a server as unavailable and destroy all meetings from it

#### Expected Parameters
```
{
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
curl --header "Content-Type: application/json" --request POST https://scalelite-hostname.com/api/servers/a783d62f-e457-4842-b23b-28a34d3a219e/panic -v
```

## Tenants API

### All Tenants
```sh 
GET /api/tenants
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
curl --request GET https://scalelite-hostname.com/api/tenants
```

### Show Tenant
```sh 
GET /api/tenants/:id
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
 curl --request GET https://scalelite-hostname.com/api/tenants/<id>
 ```

### Create Tenant
```sh 
POST /api/tenants
```

#### Expected Parameters

```
{
  "name": String,                 # Required: Name of the tenant
  "secrets": String,              # Required: Tenant secret(s)
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
curl --header "Content-Type: application/json" --request POST --data '{"name": "example-tenant", "secrets":"example-secret" }' https://scalelite-hostname.com/api/tenants -v
```

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

### Update Tenant
```sh
PUT api/tenants/:id?name=xxx
```
or

```sh 
PUT api/tenants/:id?secrets=xxx
```
or

```sh 
PUT api/tenants/:id?name=xxx&secrets=yyy
```

#### Expected Parameters

```
{
 "name": String,     # include the parameter you want updated
 "secrets": String
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
curl --header "Content-Type: application/json" --request PATCH --data '{"secrets":"new-secret" }' https://scalelite-hostname.com/api/tenants/<tenant-id> -v
```

### Remove Tenant
```sh
DELETE /api/tenants/:id
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
curl --header "Content-Type: application/json" --request DELETE https://scalelite-hostname.com/api/tenants/a783d62f-e457-4842-b23b-28a34d3a219e -v
```

Warning: Removing a tenant with data still in the database may cause some inconsistencies.
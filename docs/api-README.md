# Scalelite Management Using APIs

Scalelite comes with an API that allows for the management of tenants and servers.

## Tenants API

### Show Tenant
```sh 
GET /api/v1/tenants/:id
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

 ```javascript
 curl --request GET http://localhost:4000/api/v1/tenants/<id>
 ```

### Show All Tenants
```sh 
GET /api/v1/tenants
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

```javascript
curl --request GET http://localhost:4000/api/v1/tenants
```

### Add Tenant
```sh 
POST /api/v1/tenants
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

```javascript
curl --header "Content-Type: application/json" --request POST --data '{"name": "example-tenant", "secrets":"example-secret" }' http://localhost:4000/api/v1/tenants -v
```

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

### Update Tenant
```sh
PUT api/v1/tenants/:id?name=xxx
```
or

```sh 
PUT api/v1/tenants/:id?secrets=xxx
```
or

```sh 
PUT api/v1/tenants/:id?name=xxx&secrets=yyy
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

```javascript
curl --header "Content-Type: application/json" --request PATCH --data '{"secrets":"new-secret" }' http://localhost:4000/api/v1/tenants/<tenant-id> -v
```

### Remove Tenant
```sh
DELETE /api/v1/tenants/:id
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

```javascript
curl --header "Content-Type: application/json" --request DELETE http://localhost:4000/api/v1/tenants/a783d62f-e457-4842-b23b-28a34d3a219e -v
```

Warning: Removing a tenant with data still in the database may cause some inconsistencies.


## Servers API

### Index All Servers
```sh 
GET /servers
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

### Show Server
```sh 
GET /servers/:id
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

### Create Server
```sh 
POST /servers
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

### Update Server
```sh 
PUT /servers/:id
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

### Delete Server
```sh 
DELETE /servers/:id
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

### Panic
```sh
POST /servers/panic
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

### Successful Response
```
{
  success: {
    "Server id=<:id> has been disabled and the meetings have been destroyed"
  }
},
status: ok
```

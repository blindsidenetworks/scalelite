# Scalelite Management Using APIs

Scalelite comes with an API that allows for the management of tenants and servers, and for marking recordings whose storage has expired.

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
   "online": String,
   "state_changed_at": String
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
  "online": String,
  "state_changed_at": String
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
  "online": String,
  "state_changed_at": String
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
  "online": String,
  "state_changed_at": String
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

## Recordings API

### Expired Recording
```sh
POST /scalelite/api/expiredRecording
```

Marks a recording as deleted after its files have been removed from storage, for example by a storage
lifecycle (retention) rule. Its metadata and playback formats are removed, so it is no longer returned by
`getRecordings`. The recording files themselves are not touched.

This endpoint does not use the `checksum` parameter. The caller sends a short-lived JWT, signed with the
shared secret set in `RECORDING_EXPIRED_SECRET` (see `docs/configuration-README.md`), as a bearer token.
The secret itself is never sent. The token names the recording, so it can only be used for that one
recording, and only until it expires. If `RECORDING_EXPIRED_SECRET` is not set, every request is refused.

#### Required Headers
```
Authorization: Bearer <token>
```

#### Token

Signed with HS512 using `RECORDING_EXPIRED_SECRET`. Required claims:
```
{
  "record_id": String,             # Record ID of the recording
  "exp": Integer                   # Expiry, in seconds since the epoch; keep it short (e.g. 5 minutes)
}
```
Send no request body. If one is sent it must be JSON (like the other `scalelite/api` endpoints), and any `id` in it is ignored.

#### Responses

| Status                    | Body                    | Meaning                                                   |
| ------------------------- | ----------------------- | --------------------------------------------------------- |
| 200 OK                    | `{ "success": String }` | Recording marked as deleted, or it was already deleted    |
| 401 Unauthorized          | `{ "error": String }`   | Token missing, invalid or expired, or `RECORDING_EXPIRED_SECRET` unset |
| 404 Not Found             | `{ "error": String }`   | No recording with that `record_id`                        |
| 500 Internal Server Error | `{ "error": String }`   | Unexpected error; safe to retry with a fresh token        |

#### Example cURL

```bash
curl --header "Authorization: Bearer <token>" --request POST 'https://scalelite-hostname.com/scalelite/api/expiredRecording'
```

For example, generating the token in Ruby with the `jwt` gem:
```ruby
JWT.encode({ record_id: '<record-id>', exp: Time.now.to_i + 300 }, ENV.fetch('RECORDING_EXPIRED_SECRET'), 'HS512')
```

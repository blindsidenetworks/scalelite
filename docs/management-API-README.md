# Scalelite Management using APIs

Scalelite comes with an API that allows for the management of tenants and servers. 

## Tenants API

### Show Tenant
`GET /api/v1/tenants/:id`

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
`GET /api/v1/tenants`

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
`POST /api/v1/tenants`

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
`PUT api/v1/tenants/:id?name=xxx` or

`PUT api/v1/tenants/:id?secrets=xxx` or

`PUT api/v1/tenants/:id?name=xxx&secrets=yyy`

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
`DELETE /api/v1/tenants/:id`

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


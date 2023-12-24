# Scalelite Management using Rake Tasks

Scalelite comes with a set of rake tasks that allow for the management of tenants, tenant settings, and servers.

In a Docker deployment, these should be run from in the Docker container. You can enter the Docker container using a command like `docker exec -it scalelite-api /bin/sh`

## Rake Tasks for Tenant Management

### Show Tenants
```sh
./bin/rake tenants
```

When you run this command, Scalelite will return a list of all tenants, along with their IDs, names, and secrets. For example:

```
id: 9a870f45-ec23-4d29-828b-4673f3536d7b
        name: tenant1
        secrets: secret1
id: 4f3e4bb8-2a4e-41a6-9af8-0678c651777f
        name: tenant2
        secrets: secret2:secret2a:secret2b
```

### Add Tenant
```sh
./bin/rake tenants:add[id,secrets]
```

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

When you run this command, Scalelite will print out the ID of the newly created tenant, followed by `OK` if the operation was successful.

### Update Tenant
```sh
./bin/rake tenants:update[id,name,secrets]
```

You can update an existing tenants name or secrets using this rake command.

When you run this command, Scalelite will print out the ID of the updated tenant, followed by `OK` if the operation was successful.

### Remove Tenant
```sh
./bin/rake tenants:remove[id]
```

Warning: Removing a tenant with data still in the database may cause some inconsistencies.

### Associate Old Recordings with a Tenant
```sh
./bin/rake recordings:addToTenant[tenant-id]
```

If you are switching over from single-tenancy to multitenancy, the existing recordings will have to be transferred to the new tenant. The above task updates the recordings' metadata with the tenant id.

## Rake Tasks for Tenant Settings Management
If you have enabled multitenancy for your Scalelite deployment, you gain the ability to customize the parameters passed into the `create` and `join` calls on a per-tenant basis. This functionality empowers you to tailor the user experience according to the specific needs and preferences of each tenant.

By customizing these parameters for each tenant, you can modify various aspects of the meeting experience, such as recording settings, welcome messages, and lock settings, among others. This level of customization ensures that each tenant receives a unique and tailored experience within the Scalelite platform.

### Show Tenant Settings
```sh
./bin/rake tenantSettings
```

When you run this command, Scalelite will return a list of all settings for all tenants. For example:

```
Tenant: tenant1
  id: 18dcd4eb-769b-4c59-a441-5a9f7c0bf209
        param: param1
        value: value1
        override: true
Tenant: tenant2
  id: 9867dd51-9065-4486-9216-afb238a04748
        param: param2
        value: value2
        override: false
  id: ac7d7443-3515-4b02-bdcf-6f6452a3e00a
        param: param3
        value: value3
        override: true
```

### Add Tenant Setting
```sh
./bin/rake tenantSettings:add[tenant_id,param,value,override]
```

To add a new TenantSetting, Scalelite requires 4 values:
1. `tenant_id`: This is the unique identifier of the tenant to which you want to add the setting.
2. `param`: Specify the name of the parameter you wish to set. For example, you can use values like record, welcome, or lockSettingsLockOnJoin. To view a comprehensive list of available options, refer to the [create](https://docs.bigbluebutton.org/development/api#create) and [join](https://docs.bigbluebutton.org/development/api#join) documentation.
3. `value` -> Assign the desired value to the parameter you specified. It can be a boolean value like 'true' or 'false', a numeric value like '5' or a string like 'Welcome to BigBlueButton'.
4. `override` -> This field should be set to either 'true' or 'false'. If set to 'true', the provided value will override any value passed by the person making the create/join call. If set to 'false', the value will only be applied if the user making the create/join call does not provide any value for the specified parameter.

When you run this command, Scalelite will print out the ID of the newly created setting, followed by `OK` if the operation was successful.

### Remove Tenant Setting
```sh
./bin/rake tenantSettings:remove[id]
```

## Rake Tasks for Server Management

### Show configured server details

```sh
./bin/rake servers
```

This will print a summary of details for each server which looks like this:

```
id: 2d2d674a-c6bb-48f3-8ad4-68f33a80a5b7
        url: https://bbb1.example.com/bigbluebutton/api
        secret: 2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535
        enabled
        load: 21.0
        load multiplier: 2.0
        online
```

Particular information to note:

* `id`: This is the ID value used when updating or removing the server
* `enabled` or `disabled`: Whether the server is administratively enabled. See "Enable/Disable servers" below.
* `load`: The number of meetings on the server. New meetings will be scheduled on servers with lower load. Updated by the poll process.
* `online`: Whether the server is responding to API requests. Updated by the poll process.

### Add a server

```sh
./bin/rake servers:add[url,secret,loadMultiplier]
```

The `url` value is the complete URL to the BigBlueButton API endpoint of the server. The `/api` on the end is required.
You can find the BigBlueButton server's URL and Secret by running `bbb-conf --secret` on the BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers. If not passed, it defaults to a value of `1`.

This command will print out the ID of the newly created server, and `OK` if it was successful.
Note that servers are added in the disabled state; see "Enable a server" below to enable it.

Make sure that there is no space between the parameters [url,secret,loadMultipler] and the comma as it causes a "rake aborted!" error.

### Remove a server

```sh
./bin/rake servers:remove[id]
```

Warning: Do not remove a server which has running meetings! This will leave the database in an inconsistent state.
You should either wait for all meetings to end, or run the "Panic" function first.

### Update a server

```sh
./bin/rake servers:update[id,secret,loadMultiplier]
```

Updates the secret and load_multiplier for a BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers.

After changing the server needs to be polled at least once to see the new load.

### Disable a server

```sh
./bin/rake servers:disable[id]
```

Mark the server as disabled.
When a server is disabled, no new meetings will be started on the server.
You will not be able to join existing meetings.
The Poll process does not update disabled servers.
You should not disable a server if it has active load, you can either use the cordon option to drain the server or respond with `yes` to clear all meeting state.

### Enable a server

```sh
./bin/rake servers:enable[id]
```

Mark the server as enabled.

Note that the server won't be used for new meetings until after the next time the Poll process runs to update the load information.

### Panic a server

```sh
./bin/rake servers:panic[id]
```

Disable a server and clear all meeting state.
This method is used to recover from a crashed BigBlueButton server.
After the meeting state is cleared, anyone who tries to join a meeting that was previously on this server will instead be directed to a new meeting on a different server.

### Cordon a server

```sh
./bin/rake servers:cordon[id]
```

Mark the server as cordoned.
When a server is cordoned, no new meetings will be started on the server.
Any existing meetings will continue to run until they finish.
The Poll process continues to run on cordoned servers to update the "Online" status and detect ended meetings.
The get_meetings API would also return all the active meetings in the cordoned server.
This is useful to "drain" a server for updates without disrupting any ongoing meetings.
The server state will be updated to `disabled` by the poller once the load in server becomes zero or nil.

### Edit the load-multiplier of a server

```sh
./bin/rake servers:loadMultiplier[id,newLoadMultiplier]
```

Sets the load_multiplier for a BigBlueButton server.

The `loadMultiplier` can be used to give individual servers a higher or lower priority over other servers. A higher loadMultiplier should be placed on the weaker servers.

After changing the server needs to be polled at least once to see the new load.

### Poll all servers

```sh
./bin/rake poll:all
```

When you add a server to the pool, it may take upwards of 60 seconds (default value for `INTERVAL` for the background server polling process) before Scalelite marks the server as `online`.
You can run the above task to have it poll the server right away without waiting.

### List all meetingIds running in given servers

To list meetings in a specific servers, the following command can be used

```sh
./bin/rake servers:meeting_list["serverID1:serverID2:serverID3"]
```
To list all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake servers:meeting_list
```

### Add multiple servers through a config file

```sh
./bin/rake servers:addAll[file]
```

**Deprecated:** See `servers:sync` for a more flexible alternative.

Adds all the servers defined in a YAML file passed as an argument. The file passed in should have the following format:

```yaml
servers:
  - url: "bbb1.example.com"
    secret: "1bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
  - url: "bbb2.example.com"
    secret: "2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
  - url: "bbb3.example.com"
    secret: "3bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
```

The command will print out each added server's `url` and `id` once it has been successfully added.
Note that all servers are added in the disabled state; see "Enable a server" above to enable them.

### Configure all servers from a single YAML configuration file

```sh
./bin/rake servers:sync[path,mode,dryrun]
```

Add, remove or modify servers according to a YAML configuration file.

The `path` parameter should point to a valid YAML configuration file as described
below. Pass `-` as the path to read configuration from standard input instead.
You can use the `servers:yaml` task to bootstrap a valid configuration file from
an existing scalelite cluster.

The `mode` parameter controls how unwanted servers are removed. `mode=keep` will
not remove any servers. `mode=cordon` (the default) will remove empty servers
and cordon non-empty servers. You may have to repeat the task once these servers
are empty to actually remove them. `mode=force` will try to end all meetings on
unwanted servers and then remove them. This works similar to `servers:panic[id]`.

If `dryrun` is true, the task will run normally but not persist any changes or
end any meetings. This can be used to simulate a sync and see what would happen.

The configuration file should contain a complete list of all servers and follow
this structure:

```yaml
servers:
    <server-id>:                 # must be unique, should be a hostname
        secret: <string>         # required
        url: <string>            # default: "https://<server-id>/bigbluebutton/api"
        enabled: <bool>          # default: true
        load_multiplier: <float> # default: 1.0, must be greater than 0

    # Example for a simple server with default values
    bbb1.example.com:
        secret: "1bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"

    # Full example for a legacy server (generated id)
    02bff3a7-c95f-49d3-b1e5-c53eddd4dd68:
        secret: "2bdce5cbab581f3f20b199b970e53ae3c9d9df6392f79589bd58be020ed14535"
        url: "https://bbb2.example.com/bigbluebutton/api"
        enabled: false
        load_multiplier: 5.0
```

The task will try to reach the desired cluster state by adding, removing or
modifying servers as needed. To be more exact, the task will:

1. Read the configuration file and perform some basic sanity checks.
2. Add missing servers, based on server IDs.
3. Update configuration for existing servers (`secret`, `url` and `load_multiplier`).
4. Cordon servers that are enabled but should be disabled.
5. Enable servers that are disabled or cordoned but should be enabled.
6. Try to remove servers that are no present in the YAML configuration.
    * In `keep` mode, no servers are removed.
    * In `cordon` mode (default), only empty servers are removed. Non-empty servers are cordoned.
    * In `force` mode, servers are forcefully evicted and then removed.


### Export current server list as YAML

```sh
./bin/rake servers:yaml[verbose]
```

Prints a YAML file compatible with `servers:sync`. This task can be used to
bootstrap a cluster configuration file from an existing cluster, or get the
current cluster state in a mashine-readable format. If `verbose` is true, then
additional fields (`state`, `load` and `online`) are included. These are ignored
by `servers:sync`.


### Check the status of the entire deployment

```sh
./bin/rake status
```

This will print a table displaying a list of all servers and some basic statistics that can be used for monitoring the overall status of the deployment

```
     HOSTNAME        STATE   STATUS  MEETINGS  USERS  LARGEST MEETING  VIDEOS
 bbb1.example.com  enabled   online        12     25                7      15
 bbb2.example.com  enabled   online         4     14                4       5
```

### Manage Meetings

#### List all/specific meetings running in BigBlueButton servers

To list specific meetings, use:

```sh
./bin/rake meetings:list["meetingId1:meetingId2:meetingId3"]
```

To list all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake meetings:list
```

#### End all/specific meetings running in BigBlueButton servers

To End specific meetings, use:

```sh
./bin/rake meetings:end["meetingId1:meetingId2:meetingId3"]
```

To End all meetings running across all BigBlueButton servers, use:

```sh
./bin/rake meetings:end
```

#### Get meeting details of a meeting running in BigBlueButton server

```sh
./bin/rake meetings:info[meetingId]
```

This command will return the following meeting details of a meeting:

```
Meeting ID: 1a813084f7af08b8d19239315c170b3decedfc03-2-1
	Meeting Name: new class
	Internal MeetingID: 4445471c7ae2987ddb11db3fa2d89f8c8f86c328-1633448534301
	Created Date: Tue Oct 05 15:42:14 UTC 2021
	Recording Enabled: true
	Server id: bbb.example.com
	Serevr url: https://bbb.example.com/bigbluebutton/api/
	MetaData:
		bbb-context-name: test124
		analytics-callback-url: https://bbb1.example.com/bigbluebutton/api/analytics_callback
		bbb-recording-tags: 
		bbb-origin-server-common-name: 
		bbb-context-label: test
		bbb-origin: test
		bbb-context: test
		bbb-context-id: 2
		bbb-recording-name: new class
		bbb-origin-server-name: xx.xx.xxx.xx
		bbb-recording-description: 
		bbb-origin-tag: moodle-mod_bigbluebuttonbn
```

### Multitenancy

Scalelite supports multitenancy using subdomains for each tenant. By using subdomains, you can easily isolate each tenant's data and ensure that they can only access their own meetings and recordings.

To access their deployment, each tenant can use the following URL format: `tenant_name.sl.example.com`. Here, `tenant_name` refers to the name of the tenant, and `sl.example.com` is the domain where Scalelite is deployed.

To ensure the security of each tenant's data, we recommend using either a wildcard SSL/TLS certificate or separate DNS entries for each tenant. This will prevent unauthorized access to other tenants' data.

Each tenant will have access only to their own meetings and recordings. They will not be able to receive any information on other tenants or make any changes or actions to other tenants' resources.

To enable multitenancy in Scalelite, you only need to set `MULTITENANCY_ENABLED=true` in your environment variables.

#### Sample Tenant Setup
To create new tenants, we've added a few rake tasks to help. First, add the new tenants and secrets to Scalelite:
```sh  
docker exec -it scalelite-api /bin/bash
./bin/rake tenants:add[tenant1,secret1]
./bin/rake tenants:add[tenant2,secret2:secret2a:secret2b]
./bin/rake tenants #confirm tenants
```  
Once you have created multiple tenants in Scalelite, you will need to update the endpoint and secret for each tenant in any BigBlueButton front-end that you are using (such as Greenlight or Moodle).

To do this, you will need to set the following environment variables / configuration variables in your BigBlueButton front-end:

1.  `BIGBLUEBUTTON_ENDPOINT: tenant1.sl.example.com` - Replace `tenant1.sl.example.com` with the subdomain URL for the specific tenant.

2.  `BIGBLUEBUTTON_SECRET: secret1` - Replace `secret1` with the secret for the specific tenant.

Note that you will need to set these environment variables for each tenant in your BigBlueButton front-end. This ensures that each tenant's meetings and recordings are directed to their specific Scalelite deployment.

#### Add Tenant
`./bin/rake tenants:add[id,secrets]`

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

When you run this command, Scalelite will print out the ID of the newly created tenant, followed by `OK` if the operation was successful.

#### Update Tenant
`./bin/rake tenants:update[id,name,secrets]`

You can update an existing tenants name or secrets using this rake command.

When you run this command, Scalelite will print out the ID of the updated tenant, followed by `OK` if the operation was successful.

#### Remove Tenant
`./bin/rake tenants:remove[id]`

Warning: Removing a tenant with data still in the database may cause some inconsistencies.

#### Show Tenants
`./bin/rake tenants`

When you run this command, Scalelite will return a list of all tenants, along with their IDs, names, and secrets. For example:

```
id: 9a870f45-ec23-4d29-828b-4673f3536d7b
        name: tenant1
        secrets: secret1
id: 4f3e4bb8-2a4e-41a6-9af8-0678c651777f
        name: tenant2
        secrets: secret2:secret2a:secret2b
```
#### Associate Old Recordings with a Tenant
`./bin/rake recordings:addToTenant[tenant-id]`

If you are switching over from single-tenancy to multitenancy, the existing recordings will have to be transferred to the new tenant. The above task updates the recordings' metadata with the tenant id.

### Tenant Settings

If you have enabled multitenancy for your Scalelite deployment, you gain the ability to customize the parameters passed into the `create` and `join` calls on a per-tenant basis. This functionality empowers you to tailor the user experience according to the specific needs and preferences of each tenant.

By customizing these parameters for each tenant, you can modify various aspects of the meeting experience, such as recording settings, welcome messages, and lock settings, among others. This level of customization ensures that each tenant receives a unique and tailored experience within the Scalelite platform.

#### Add Tenant Setting
`./bin/rake tenantSettings:add[tenant_id,param,value,override]`

To add a new TenantSetting, Scalelite requires 4 values:
1. `tenant_id`: This is the unique identifier of the tenant to which you want to add the setting.
2. `param`: Specify the name of the parameter you wish to set. For example, you can use values like record, welcome, or lockSettingsLockOnJoin. To view a comprehensive list of available options, refer to the [create](https://docs.bigbluebutton.org/development/api#create) and [join](https://docs.bigbluebutton.org/development/api#join) documentation.
3. `value` -> Assign the desired value to the parameter you specified. It can be a boolean value like 'true' or 'false', a numeric value like '5' or a string like 'Welcome to BigBlueButton'.
4. `override` -> This field should be set to either 'true' or 'false'. If set to 'true', the provided value will override any value passed by the person making the create/join call. If set to 'false', the value will only be applied if the user making the create/join call does not provide any value for the specified parameter.

When you run this command, Scalelite will print out the ID of the newly created setting, followed by `OK` if the operation was successful.

#### Remove Tenant Setting
`./bin/rake tenantSettings:remove[id]`

#### Show Tenant Settings
`./bin/rake tenantSettings`

When you run this command, Scalelite will return a list of all settings for all tenants. For example:

```
Tenant: tenant1
  id: 18dcd4eb-769b-4c59-a441-5a9f7c0bf209
        param: param1
        value: value1
        override: true
Tenant: tenant2
  id: 9867dd51-9065-4486-9216-afb238a04748
        param: param2
        value: value2
        override: false
  id: ac7d7443-3515-4b02-bdcf-6f6452a3e00a
        param: param3
        value: value3
        override: true
```

# Scalelite Management using Rake Tasks

Scalelite comes with a set of rake tasks that allow for the management of tenants, tenant settings, and servers. 

## Rake Tasks for Tenant Management

### Show Tenants
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

### Add Tenant
`./bin/rake tenants:add[id,secrets]`

If you need to add multiple secrets for a tenant, you can provide a colon-separated (`:`) list of secrets when creating the tenant in Scalelite.

When you run this command, Scalelite will print out the ID of the newly created tenant, followed by `OK` if the operation was successful.

### Update Tenant
`./bin/rake tenants:update[id,name,secrets]`

You can update an existing tenants name or secrets using this rake command.

When you run this command, Scalelite will print out the ID of the updated tenant, followed by `OK` if the operation was successful.

### Remove Tenant
`./bin/rake tenants:remove[id]`

Warning: Removing a tenant with data still in the database may cause some inconsistencies.

### Associate Old Recordings with a Tenant
`./bin/rake recordings:addToTenant[tenant-id]`

If you are switching over from single-tenancy to multitenancy, the existing recordings will have to be transferred to the new tenant. The above task updates the recordings' metadata with the tenant id.

## Rake Tasks for Tenant Settings Management
If you have enabled multitenancy for your Scalelite deployment, you gain the ability to customize the parameters passed into the `create` and `join` calls on a per-tenant basis. This functionality empowers you to tailor the user experience according to the specific needs and preferences of each tenant.

By customizing these parameters for each tenant, you can modify various aspects of the meeting experience, such as recording settings, welcome messages, and lock settings, among others. This level of customization ensures that each tenant receives a unique and tailored experience within the Scalelite platform.

### Show Tenant Settings
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

### Add Tenant Setting
`./bin/rake tenantSettings:add[tenant_id,param,value,override]`

To add a new TenantSetting, Scalelite requires 4 values:
1. `tenant_id`: This is the unique identifier of the tenant to which you want to add the setting.
2. `param`: Specify the name of the parameter you wish to set. For example, you can use values like record, welcome, or lockSettingsLockOnJoin. To view a comprehensive list of available options, refer to the [create](https://docs.bigbluebutton.org/development/api#create) and [join](https://docs.bigbluebutton.org/development/api#join) documentation.
3. `value` -> Assign the desired value to the parameter you specified. It can be a boolean value like 'true' or 'false', a numeric value like '5' or a string like 'Welcome to BigBlueButton'.
4. `override` -> This field should be set to either 'true' or 'false'. If set to 'true', the provided value will override any value passed by the person making the create/join call. If set to 'false', the value will only be applied if the user making the create/join call does not provide any value for the specified parameter.

When you run this command, Scalelite will print out the ID of the newly created setting, followed by `OK` if the operation was successful.

### Remove Tenant Setting
`./bin/rake tenantSettings:remove[id]`

## Rake Tasks for Server Management
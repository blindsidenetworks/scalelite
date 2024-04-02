# Tagged Servers

## Description

This feature allows to provide users the choice of specially configured servers (e.g. optimized for very large conferences or running newer BBB versions), without requiring a dedicated Loadbalancer + Frontend infrastructures. It works by first assigning so-called tags to certain servers and then referencing the tag via a meta-parameter in the create API call, to request placing the meeting on a server with corresponding tag. Because the create call is made by the BBB frontend, the feature needs to be supported by the frontend.

## How to tag servers in Scalelite

When adding a server in Scalelite, you can optionally specify a non-empty string as "tag" for the server. Per default, it is nil.

This works for all supported ways of adding servers: Per `rake servers:add` task, per `addServer` API call or per `rake servers:sync` from YAML file. The same is true for the `rake servers:update` task and `updateServer` call. For more details, see `api-README.md` and `rake-README.md`.

## Create call with server-tag metaparameter

A create API call with a meta feature is supposed to work as follows:

1) When making a "create" API call towards Scalelite, you can optionally pass a meta_server-tag string as parameter. If passed, it will be handled as follows:
2) If the last character of meta_server-tag is not a '!', the tag will will be intepreted as *optional*. The meeting will be created on the lowest load server with the corresponding tag, if any is available, or on the lowest load untagged (i.e. tag == nil) server otherwise.
3) If the last character of meta_server-tag is a '!', this character will be stripped and the remaining tag will be interpreted as *required*. The meeting will be created on the lowest load server with the corresponding tag or fail to be created (with specific error message), if no matching server is available.

NOTE: Create calls without or with ''/'!' as meta_server-tag will only match untagged servers. So, for a frontend unaware of the feature, SL will behave as previously if a pool of untagged ("default") servers is maintained. It is recommended to always add your default servers as untagged servers.


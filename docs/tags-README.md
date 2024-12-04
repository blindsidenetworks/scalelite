# Tagged Servers

## Description

This feature allows to provide users the choice of specially configured servers (e.g. optimized for very large conferences or running newer BBB versions), without requiring a dedicated Loadbalancer + Frontend infrastructures. It works by first assigning so-called tags to certain servers and then referencing the tag via a meta-parameter in the create API call, to request placing the meeting on a server with corresponding tag. Because the create call is made by the BBB frontend, the feature needs to be supported by the frontend.

## How to tag servers in Scalelite

When adding a server in Scalelite, you can optionally specify a non-empty string as "tag" for the server. Per default, it is nil.

This works for all supported ways of adding servers: Per `rake servers:add` task, per `addServer` API call or per `rake servers:sync` from YAML file. The same is true for the `rake servers:update` task and `updateServer` call. For more details, see `api-README.md` and `rake-README.md`.

## Create call with server-tag metaparameter

A create API call with a meta feature is supposed to work as follows:

1) When making a "create" API call towards Scalelite, you can optionally pass a meta_server-tag parameter with a string value. The string can be a single tag or a comma-separated list of tags and may additionally contain a '!' as last character. It will be handled as follows:
2) If the last character of meta_server-tag is not a '!', the tags will will be intepreted as *optional*. The meeting will be created on the least loaded server with a tag matching one of the passed tags (the special tag 'none' will match untagged servers), if any is available, or on the least loaded untagged server otherwise.
3) If the last character of meta_server-tag is a '!', this character will be stripped and the remaining tags will be interpreted as *required*. The meeting will be created on the least loaded server with a tag matching one of the passed tags (the special tag 'none' will match untagged servers) or *fail* to be created (with a specific error message), if no matching server is available.

NOTE: Create calls without or with ''/'!' as meta_server-tag will only match untagged servers. So, for a frontend unaware of the feature, SL will behave as previously if a pool of untagged ("default") servers is maintained. It is recommended to always add your default servers as untagged servers.

### Examples

Consider the following setup:
`$ bundle exec rake status`
```
HOSTNAME   STATE   STATUS  MEETINGS  USERS  LARGEST MEETING  VIDEOS  LOAD   BBB VERSION   TAG  
 bbb-1    enabled  online  1         2      2                0        3.0      3.0.0      test
 bbb-2    enabled  online  1         1      1                0        2.0      3.0.0
 bbb-3    enabled  online  0         0      0                0        0.0      3.0.0 
 bbb-4    enabled  online  1         1      1                0        2.0      3.0.0      test2
 ```

Now, consider the following examples of `meta_server-tag` parameters:
- Passing `meta_server-tag=` or `meta_server-tag=!` or omitting the parameter altogether are all equivalent and will place the meeting on `bbb-3` (least loaded untagged).
- Passing `meta_server-tag=test` or `meta_server-tag=test!` will place the meeting on `bbb-1` (the only match).
- Passing `meta_server-tag=test,test2` or `meta_server-tag=test,test2!` will place the meeting on `bbb-4` (least loaded match).
- Passing `meta_server-tag=none` or `meta_server-tag=none!` will place the meeting on `bbb-3` ) (least loaded match).
- Passing `meta_server-tag=test3` will place the meeting on `bbb-3` (fallback to least loaded untagged).
- Passing `meta_server-tag=test3!` will place the meeting on `bbb-3` (fallback to least loaded untagged).
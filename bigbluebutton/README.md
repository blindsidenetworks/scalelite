# Scalelite Recording Transfer scripts for BigBlueButton

This directory contains scripts to be installed on the BigBlueButton server to handle transferring published recordings from BigBlueButton to a central storage system used by Scalelite.

## Installation

On each BigBlueButton server, install the following files to the listed paths:

* `scalelite_post_publish.rb`: install to the directory `/usr/local/bigbluebutton/core/scripts/post_publish`
* `scalelite.yml`: install to the directory `/usr/local/bigbluebutton/core/scripts`

## Configuration

The file `scalelite.yml` contains configuration for the transfer script.
It has some documentation in the comments, but here is a quick summary of the changes that may be needed.

### Shared filesystem (e.g. NFS mount)

If the Scalelite recordings spool directory is mounted on the BigBlueButton server as a shared filesystem, then you only need to set `spool_dir` to the location where the spool directory is mounted.
Ensure that the `bigbluebutton` user has permission to enter and write to the spool directory.

### Transfer using rsync over SSH

To transfer recording files over SSH, you will need to set up an SSH key and SSH configuration for the `bigbluebutton` user.

You can log in as the `bigbluebutton` user with the command:

```sh
su - bigbluebutton -s /bin/bash
```

All of the following example commands assume you are running as the `bigbluebutton` user.

You will need to create the `.ssh` directory if it doesn't exist:

```sh
mkdir -p ~/.ssh ; chmod 0700 ~/.ssh
```

Create a new SSH key for the recording transfer to use:
```sh
ssh-keygen -t ed25519 -N '' -f ~/.ssh/scalelite
```

This will create a file `~/.ssh/scalelite.pub` with the public key, you will have to add that public key to the `authorized_keys` file on the destination system.

You can then edit the file `~/.ssh/config` and add a section to configure the user and key to use.
It will look something like this:

```
Host scalelite-recording.example.com
        User scalelite-spool
        IdentityFile ~/.ssh/scalelite
```

Make sure to test the configuration by running `ssh scalelite-recording.example.com` as the BigBlueButton user.
You should do this at least once to make sure to accept the remote server's public key, if needed.

Finally (after switching back to root), set the `spool_dir` setting in `scalelite.yml` to the rsync destination, which will be formatted like `scalelite-recording.example.com:/path/to/spool`. It will automatically use the username and private key configured in the `~/.ssh/config` file.

### Other configurations

If you need to customize the rsync command (for example, to pass the `--rsh` option to set up a tunnel), you can add extra rsync command line arguments via the `extra_rsync_opts` array in `scalelite.yml`.

# Setting up a shared volume for recordings
## Mounting the shared volume
A shared volume should be mounted via NFS on the following systems:

- BigBlueButton servers
- Host system for `scalelite-nginx` Docker container
- Host system for `scalelite-recording-importer` Docker container

The mount point should be different from any of the paths used by stock BigBlueButton. A good choice is `/mnt/scalelite-recordings` - this is the path that will be referenced below. If you use a different path, modify the path in the instructions to match.

## Setting up directory structure and permissions
It is critical to note that NFS file permissions are based on numeric UID/GID values, and not by user and group names. As a result, it is important to set up users and groups with consistent numbers on the various services.

The docker containers that operate on recording files use a fixed UID value of 1000.
A fresh BigBlueButton server install will usually have a “bigbluebutton” user with UID 997, but this UID is not guaranteed.

In order to solve the consistency issue, you should create a new group on the BigBlueButton server with a consistent GID to control write permissions. Pick a GID that's unused on the server. In the examples below, I use 2000.

**On each BigBlueButton server**, run these commands to create the group and add the bigbluebutton user to the group:

```
# Create a new group with GID 2000
groupadd -g 2000 scalelite-spool
# Add the bigbluebutton user to the group
usermod -a -G scalelite-spool bigbluebutton
```

**On the Scalelite server**, you are now ready to set up the directory structure and permissions on the shared volume. Assuming you're using the mountpoint `/mnt/scalelite-recordings` the commands to do so will look like this:

```
# Create the spool directory for recording transfer from BigBlueButton
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/spool
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/spool
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/spool

# Create the temporary (working) directory for recording import
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/recording/scalelite

# Create the directory for published recordings
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/published
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/published
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/published

# Create the directory for unpublished recordings
mkdir -p /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chown 1000:2000 /mnt/scalelite-recordings/var/bigbluebutton/unpublished
chmod 0775 /mnt/scalelite-recordings/var/bigbluebutton/unpublished
```

## Configuring the BigBlueButton recording transfer
**On each BigBlueButton server**

The `scalelite_post_publish.rb` post publish script should be installed with its configuration file as described in [this document](bigbluebutton/README.md).

To match the mount configuration described in this document, the configuration file `/usr/local/bigbluebutton/core/scripts/scalelite.yml` should have the following contents:

```
# Local directory for temporary storage of working files
work_dir: /var/bigbluebutton/recording/scalelite
# Directory to place recording files for scalelite to import
spool_dir: /mnt/scalelite-recordings/var/bigbluebutton/spool
# Extra rsync options for keeping the permissions of the copied files as defined for the directories.
# extra_rsync_opts: ["-av", "--no-owner", "--chmod=F664"]
```

**Next step is only needed if you have existing recordings on your BigBlueButton server**

Once the configuration is performed, you can run the provided `scalelite_batch_import.sh` script to transfer any existing recordings from the BigBlueButton server to Scalelite.

Once the recording transfer has been tested, you can **optionally** enable recording automatic deletion on the BigBlueButton server to remove the local copies of the recordings and free up disk space.

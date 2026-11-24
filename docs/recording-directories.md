# Recording Directories

## What it does

Out of the box Scalelite keeps every recording in one place: a published playback format in
`RECORDING_PUBLISH_DIR/<format>/<record id>`, an unpublished one in the same path below
`RECORDING_UNPUBLISH_DIR`, whichever tenant it belongs to.

With `RECORDING_DIR_PER_TENANT=true` a tenant can be **given a directory of its own**, for example on another
volume, and its recordings are kept there instead:

```sh
./bin/rake tenants:recording_dir[<tenant-id>,/mnt/data1/tenant1]
```

```
/var/bigbluebutton/published/
    presentation/
        <record id A>/                  every other recording, as before
        <record id B> -> /mnt/data1/tenant1/published/presentation/<record id B>
/mnt/data1/tenant1/
    published/presentation/<record id B>/       a recording of tenant1
    unpublished/presentation/<record id C>/     an unpublished recording of tenant1
```

**The setting alone moves nothing.** The recordings of a tenant that was not given a directory, and the ones
that belong to no tenant, stay exactly where they always were, with the setting on or off. Only a tenant with a
directory is treated differently, and only while the setting is on.

It needs multitenancy (`MULTITENANCY_ENABLED=true`), since there is no tenant without it, and it does not apply
to recordings kept in S3, which have `S3_RECORDING_TENANT_PREFIX`.

A recording belongs to a tenant through the `tenant-id` Scalelite puts into the metadata of every meeting the
tenant creates, the same way `getRecordings` tells tenants apart.

## The old path stays, as a link

Everything that reads a recording knows it by `published/<format>/<record id>`: the web server, the playback
URLs a frontend has stored, and the scripts that walk the publish directory, such as a retention job. That
path is kept. For a recording whose files are in the directory of a tenant it is a symbolic link to them, as
`<record id B>` above.

So nothing else has to learn about tenants:

- **The web server needs no new configuration**, only the volume (see below). It follows the link. This holds
  for the nginx image of this repository and for a layout that serves recordings from another container, such
  as `bbb-playback-proxy`, including format-specific locations that name `published/<format>/` in full.
- **Playback URLs do not change**, and the playback requests are answered without a single extra lookup.
- **Scripts that walk `published/<format>/` find every recording where they always did.**
- A recording keeps playing when the directory of its tenant is changed and when the setting is switched off
  again.

An unpublished recording has no link: nothing but Scalelite reads it, and the web server must not reach it.

This needs a file system for the publish directory that can hold symbolic links, which NFS, ext4 and XFS do.
Where a link cannot be created the import fails and the recording stays in the spool to be tried again, rather
than being imported to a place the web server cannot find.

## The directory of a tenant

```sh
./bin/rake tenants:recording_dir[<tenant-id>,/mnt/data1/tenant1]   # give it one
./bin/rake tenants:recording_dir[<tenant-id>,]                     # take it away again
./bin/rake tenants                                                 # shows it, for the tenants that have one
```

Scalelite keeps a `published` and an `unpublished` directory inside it, laid out like the shared ones. Having
both on the same volume keeps publishing and unpublishing a rename, where it would otherwise be a copy to
another file system and back.

Three things have to be true of the directory:

- **It is mounted under the same path** in the API container, in the recording importer and in the container
  of the web server that serves the recordings. The link at `published/<format>/<record id>` carries that
  path, and each of them has to be able to follow it. The path given to the rake task is the one **inside the
  containers**, not the one on the host: with scalelite-run the recordings are in
  `/mnt/scalelite-recordings/var/bigbluebutton` on the host and in `/var/bigbluebutton` in the containers. A
  path that only the host has is refused.

  The web server is the one that gets forgotten, and the one Scalelite cannot check. In the scalelite-run
  layout its container has the publish directory and nothing else of the volume, so a directory **next to**
  `published`, such as `/var/bigbluebutton/tenant1`, exists in the API container and not in the web server:
  every recording moved there answers 404 until `<directory>/published` is mounted into that container as
  well. That `/var/bigbluebutton` is a link to the volume on the host changes nothing, since the container
  does not have the host's link. To see what the web server sees:

  ```sh
  docker exec scalelite-recordings ls /var/bigbluebutton/tenant1/published
  ```

  A directory **inside** the publish directory, such as `/var/bigbluebutton/published/tenants/tenant1`, needs
  no mount of its own: the web server has it already, and the link to it is relative.
- **It exists and the containers can write to it** (they run as UID 1000, see
  [the shared volume](sharedvolume-README.md)). Scalelite never creates it: where it is missing the volume
  behind it is not mounted, and creating it would put the recordings into the container, to be lost with it.
- **Its path is plain**: absolute, made of letters, digits, `.`, `_` and `-`.

`rake tenants:recording_dir` refuses a directory that is not a writable directory in the container it is run
in, so run it in the API container. It says which of the three it is: a directory that does not exist there (a
path as only the host has it, or a volume that is not mounted), a path that is not a directory, or a directory
the user of the container cannot write to. Should the directory go missing later, because a volume is not mounted, the
recordings of that tenant are **not imported and not lost**: the import fails, the error is logged with every
pass of the importer, and the tar stays in the spool until the directory is back.

The directory can only be set with the rake task, not through the tenant API: it is a path on the server, and
the API hands out no way to choose one. `getTenantInfo` shows it, as `recording_dir`, for a tenant that has one.

### Example: a second volume next to the recordings

The recordings are on the host in `/mnt/scalelite-recordings/var/bigbluebutton`, which the containers see as
`/var/bigbluebutton`, as [scalelite-run](https://github.com/blindsidenetworks/scalelite-run) sets it up. A
second volume is mounted on the host at `/mnt/data1`, and tenant `tenant1` is to keep its recordings there.

1. Create the directory on the host and hand it to the user of the containers:

   ```sh
   mkdir -p /mnt/data1/tenant1
   chown 1000:2000 /mnt/data1/tenant1
   ```

2. Mount the volume **under the same path as on the host** in the three containers, in a
   `docker-compose.override.yml` next to the `docker-compose.yml`. Mounting the whole volume once means the
   next tenant only needs a directory, not another change here:

   ```yaml
   services:
     scalelite-api:
       volumes:
         - /mnt/data1:/mnt/data1
     scalelite-recording-importer:
       volumes:
         - /mnt/data1:/mnt/data1
     scalelite-recordings:   # whichever container serves /var/bigbluebutton/published
       volumes:
         - /mnt/data1:/mnt/data1:ro
   ```

   Because the path is the same inside and outside, the links also resolve on the host, so a script that goes
   through `/mnt/scalelite-recordings/var/bigbluebutton/published` there keeps finding every recording. The web
   server only ever follows links into a `published` directory; mount `/mnt/data1/tenant1/published` alone, at
   that same path, if it is to see nothing else of the volume.

3. Set `RECORDING_DIR_PER_TENANT=true` in the `.env` the API and the importer read, and create the containers
   again: `docker compose up -d`.

4. Give the tenant the directory, make sure the web server sees it, and move what the tenant already has:

   ```sh
   docker exec -it scalelite-api ./bin/rake "tenants:recording_dir[<tenant-id>,/mnt/data1/tenant1]"
   docker exec scalelite-recordings ls -d /mnt/data1/tenant1                 # has to be there
   docker exec -it scalelite-api ./bin/rake "recordings:relocate[<tenant-id>]"   # says what it would move and asks
   ```

## Moving recordings that are there already

Giving a tenant a directory does not move its recordings: new ones go there from then on, and the ones that
are there already stay where they are and keep playing. Move them whenever it suits, in a container that has
the recordings, which the API container does:

```sh
./bin/rake recordings:relocate                  # says what it would move, asks, then moves it
./bin/rake recordings:relocate[<tenant-id>]     # the same for the recordings of one tenant
```

```
214 playback formats will be moved and 0 linked again.
        214 from /var/bigbluebutton/published to /mnt/data1/tenant1/published
WARNING: the web server container must see these directories under the same path, or the recordings answer 404:
        /mnt/data1/tenant1/published
Continue? [y/N]
y
/var/bigbluebutton/published/presentation/<record id> -> /mnt/data1/tenant1/published/presentation/<record id>
...
214 playback formats moved, 0 linked again, 1038 already in place, 0 not found, 0 in more than one place, 0 failed
```

The task goes through every recording in the database, or every recording of the tenant it is given, works
out where each playback format belongs under the settings of the moment, and moves it there if it is anywhere
else. To another volume the files are copied, which takes as long as copying them takes.

While `RECORDING_DIR_PER_TENANT` is off, the directories of tenants are not used, and the task starts with a
`NOTE` that says so for the tenants concerned. That is what switching it off is about, and also what a setting
that was forgotten looks like: every recording is already in place.

**It asks before it moves anything.** It first works out what there is to move, says how many playback
formats would go from which directory into which, and waits for `y` or `yes`; any other answer, and no answer
at all, moves nothing and ends the task with a non-zero status. So to only look at what would happen, answer
`n`. Where recordings are about to be moved into a directory outside the publish directory it names that
directory first, because the web server has to see it and nothing but a look into its container can tell
whether it does. With nothing to move it does not ask. Run it with a terminal (`docker exec -it`); a script
that knows what it is doing sends the answer:
`echo y | docker exec -i scalelite-api ./bin/rake recordings:relocate`.

It can be run as often as needed and while Scalelite is in use: each recording is locked while it is moved,
the same way `publishRecordings` locks it. A recording that is played back at that moment misses its files for
the instant between the move and the new link; when it is moved to another volume, for as long as it takes to
remove the old copy once the new one is complete. It never deletes anything:

| Reported as | What it means |
| --- | --- |
| `moved` | the files were somewhere else and are now where they belong |
| `linked again` | the files were in place but the link to them was missing or stale, and was put right |
| `already in place` | nothing to do |
| `not found` | the database knows the format, the disk does not: the files were removed by hand, or the task runs where the recordings are not mounted |
| `in more than one place` | the same format lies in two directories. Nothing can tell which copy is the good one, so both are left and listed for somebody to look at |
| `failed` | the move raised an error, which is printed; most often a directory of a tenant that is not mounted |

## Where a recording is looked for

Where a recording *belongs* follows from the settings of the moment. Where it *is* can be a place it belonged
in before: its tenant was given a directory after it was made, or the setting was switched off. So Scalelite
never assumes. Before it touches the files of a recording it looks for them in the directory of its tenant
and in the shared directories, following the link at the old path wherever that leads, and if they are in none
of these, in any other directory that stands next to the playback formats there.

| Operation | What happens |
| --- | --- |
| import | the files go where they belong, and whatever an earlier import of the same format left anywhere is replaced |
| `publishRecordings` | the files are found wherever they are and moved to where they belong in their new state, so a recording that was never relocated moves the first time it is published or unpublished |
| `deleteRecordings` | every format is removed from every place it is in, published or not, together with its links |
| playback | not involved: the web server follows the link |

## Changing or taking away a directory, and removing a tenant

Changing the directory of a tenant, or taking it away, moves the **unpublished** recordings in it along:
`rake tenants:recording_dir` puts them where they belong now, the new directory or the shared one, and prints
every move. No link leads to an unpublished recording, so left in a directory the tenant no longer has nothing
would find it again, neither to publish nor to delete it. Each one is locked while it is moved, the same way
`publishRecordings` locks it.

**Published recordings** keep playing from the old directory through their links, and `rake recordings:relocate`
moves them to the new place as long as the old directory is still mounted.

The task removes nothing. What it cannot move it leaves where it is and names, each on a line of its own:

| Left because | What to do |
| --- | --- |
| the recording has the same format in a place Scalelite looks already | compare the two copies and remove the one that is not wanted |
| the recording was deleted in Scalelite | remove the files by hand: Scalelite no longer knows them |
| Scalelite does not know the recording, or it belongs to another tenant | look at it; Scalelite does not touch it |
| the move failed | move `<old directory>/unpublished/<format>/<record id>` to the place the error names, as it is |

Where the old directory is not there at all, because its volume is not mounted, the task says so and moves
nothing. Once it is mounted again, move `<old directory>/unpublished/<format>/<record id>` to the place the
warning names by hand. Better: mount it before the directory is changed.

The recordings of a tenant that was removed belong to no tenant any more. They keep playing, and
`rake recordings:relocate` moves the published ones back to the shared directories. Take the directory away,
which moves the unpublished recordings out, and relocate **before** removing the tenant: the directory is
forgotten with the tenant, and whatever is still in it with it.

## Switching it off

Set `RECORDING_DIR_PER_TENANT=false` and restart. The directories of the tenants are no longer used: new
recordings go to the shared directories, the existing ones keep playing through their links, and
`rake recordings:relocate` moves them back, replacing each link with the files it pointed to. Do that while
the directories of the tenants are still mounted.

## What else to know

- **Disk usage.** The files of a tenant with a directory are in that directory, so `du -sh` of it is what the
  tenant keeps on disk.
- **Empty directories.** A directory that the last recording was moved out of or deleted from is left
  standing. Removing it while a recording is on its way into it would lose that recording, so Scalelite never
  does; an empty one can be removed by hand.
- **Links made by hand.** Scalelite follows a link at `published/<format>/<record id>` only if it leads to a
  directory that carries the same record ID. A link to anywhere else is treated as a recording without files.
- **Backups.** A copy that keeps symbolic links, such as `rsync -a`, keeps the layout, and the directory of a
  tenant has to be backed up as well. A copy that follows links stores the recordings of such a tenant in both.
- **Deleting.** Remove recordings through `deleteRecordings`, as before, not by removing a directory:
  Scalelite is not told about files that disappear, and would keep listing the recording.

## Privacy

Nothing about a meeting or the people in it is added to a path, and nothing is logged that was not logged
before. The directory of a tenant is whatever the operator names it. Keeping the recordings of a tenant
together makes it possible to give them a volume, a quota or a backup of their own, and to see what one tenant
keeps without reading a database. `deleteRecordings` removes the files of a recording from every place they
are in, the unpublished ones included; `rake tenants:recording_dir` moves the unpublished recordings out of a
directory it takes away, so that none is left where `deleteRecordings` would not find it.

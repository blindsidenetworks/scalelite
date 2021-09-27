# Protected_Recordings

Protected Recordings is a feature introduced in the Scalelite version 1.2, which gives the users of scalelite the ability to protect their recordings from being used by external users. When this feature is enabled, all the playback links for the recordings will have a one-time use token associated with it and Scalelite will verify that a) the tocken has never been consumed, or b) the user accessing the recording is the one who consumed the token originally. Otherwise Scalelite espondswith a 404 error.

This forces the users to go though the integration (such as Moodle), not letting them share the recording links.

## Setup Protected_Recordings feature

In order to use the protected_recordings the following variables need to  added to the `/etc/default/scalelite` file:

`SCALELITE_TAG`: Change the version in `SCALELITE_TAG=v1.2`.
`PROTECTED_RECORDINGS_ENABLED`: Applies to the recording import process. If set to "true", then newly imported recordings will have protected links enabled. Default is "false".
`PROTECTED_RECORDINGS_TOKEN_TIMEOUT`: Protected recording link token timeout in minutes. This is the amount of time that the one-time-use link returned in getRecordings calls will be valid for. Defaults to 60 minutes (1 hour).
`PROTECTED_RECORDINGS_TIMEOUT`: Protected recordings resource access cookie timeout in minutes. This is the amount of time that a user will be granted access to view a recording for after clicking on the one-time-use link. Defaults to 360 minutes (6 hours).

And restart scalelite right after

`systemctl restart scalelite.target`.

### Troubleshooting 

* 404 error while trying to playback the recordings: This error can occur when the protected_recordings link has no or invalid token or when the cookie associated with that link has expired. To fix the issue you can reload the recordings preview page(which internally calls the get_recordings api), which would fetch a new token for the protected_recordings. Additionally you can also verify if the cookies are getting set properly in the browser.

* Debugging scalelite-recording-importer.service related issues: You can check the status of scalelite-nginx.service using the command `systemctl status scalelite-nginx.service`,you can also tail the logs using `journalctl -u scalelite-nginx.service -f`.

* Debugging scalelite-recording-importer.service related issues: You can check the status of scalelite-recording-importer.service using the command `systemctl status scalelite-recording-importer.service`,you can also tail the logs using `journalctl -u scalelite-recording-importer.service -f`.

* Protected Recordings are still playable for external users: You can verify if the scalelite-nginx.service version running is `v1.2-nginx` or later, by running the command `docker ps`.

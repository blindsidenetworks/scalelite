# Protected Recordings

Protected Recordings is a feature introduced in version 1.2, which gives system administrators the ability to protect their recordings from being shared publicly. When this feature is enabled, all the playback links for the recordings will have a one-time use token associated with it and Scalelite will verify that a) the token has never been consumed, or b) the user accessing the recording is the one who consumed the token originally. Otherwise Scalelite responds with a 404 error.

This forces the users to go through the integration (such as Moodle), not letting them share the recording links.

## Setup Protected Recordings feature

In order to use the Protected Recordings feature the following variables need to be added to the `/etc/default/scalelite` file:

`SCALELITE_TAG`: Change the version in `SCALELITE_TAG=v1.2`.
`PROTECTED_RECORDINGS_ENABLED`: Applies to the recording import process. If set to "true", then newly imported recordings will have protected links enabled. Default is "false".
`PROTECTED_RECORDINGS_TOKEN_TIMEOUT`: Protected recording link token timeout in minutes. This is the amount of time that the one-time-use link returned in getRecordings calls will be valid for. Defaults to 60 minutes (1 hour).
`PROTECTED_RECORDINGS_TIMEOUT`: Protected recordings resource access cookie timeout in minutes. This is the amount of time that a user will be granted access to view a recording for after clicking on the one-time-use link. Defaults to 360 minutes (6 hours).

And restart scalelite right after

`systemctl restart scalelite.target`.

### Troubleshooting

* 404 error while trying to playback the recording: This error can occur when the protected link has no token, the token is invalid or the cookie associated with that link has expired. To fix the issue a new getRecordings request needs to be performed. This can be done through the integration by reloading the page that shows the links to the recording. Additionally it is possible to verify in the browser if that the cookies are being set properly.

* Debugging scalelite-recording-importer.service related issues: It would be necessary to check the status of scalelite-nginx.service using the command `systemctl status scalelite-nginx.service`. It is also possible to do so by tailing the logs using `journalctl -u scalelite-nginx.service -f`.

* Debugging scalelite-recording-importer.service related issues: It would be necessary to check the status of scalelite-recording-importer.service using the command `systemctl status scalelite-recording-importer.service`. It is also possible to do so by tailing the logs using `journalctl -u scalelite-recording-importer.service -f`.

* Protected Recordings are still playable for external users: This would be normally caused because the front-end proxy is failing to redirect the requests to the application. The scalelite-nginx.service version can be verified by running the command `docker ps`. The current version should be `v1.2-nginx` or later.

* Users are able to see the recordings only once. This is the normal behaviour, but users should also be allowed to replay the recording even if they refresh the browser. If that is not happening, it is likely that the browser has cookies disabled.

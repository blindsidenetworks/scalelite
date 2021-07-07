#!/bin/bash 

# Place this file in /etc/cron.daily
#

# Delete sent recording after 4 days
MAXAGE=4

# Delete events files after 4 days
EVENTS_MAXAGE=4

LOGFILE=/var/log/bigbluebutton/bbb-sender-cleanup.log

shopt -s nullglob

NOW=$(date +%s)

echo "$(date --rfc-3339=seconds) Deleting sent recordings older than ${MAXAGE} days" >>"${LOGFILE}"

# Iterate through the list of recordings for which sender publishing has
# completed
for donefile in /var/bigbluebutton/recording/status/published/*-sender.done ; do
        MTIME=$(stat -c %Y "${donefile}")
        # Check the age of the recording
        if [ $(( ( $NOW - $MTIME ) / 86400 )) -gt $MAXAGE ]; then
                MEETING_ID=$(basename "${donefile}")
                MEETING_ID=${MEETING_ID%-sender.done}
                echo "${MEETING_ID}" >> "${LOGFILE}"

                bbb-record --delete "${MEETING_ID}" >> "${LOGFILE}"
        fi
done

echo "$(date --rfc-3339=seconds) Deleting events files older than ${EVENTS_MAXAGE}"
for eventsfile in /var/bigbluebutton/events/*/events.xml ; do
        MTIME=$(stat -c %Y "${eventsfile}")
        if [ $(( ( $NOW - $MTIME ) / 86400 )) -gt $EVENTS_MAXAGE ]; then
                EVENTS_DIR="${eventsfile%/*}"
                rm -rv "${EVENTS_DIR}" >>"${LOGFILE}" 2>&1
        fi
done


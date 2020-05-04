#!/bin/bash

# Build these containers...

ORG=oeru
BASE=scalelite
TARGETS="build api poller recording-importer bbb-playback nginx"
DB="docker build"
DP="docker push"
echo "create containers"

for TARGET in $TARGETS 
do
    echo
    echo "************ start $TARGET *************"
    echo "Building docker container $ORG/$BASE-$TARGET"
    $DB --target $TARGET --tag $ORG/$BASE-$TARGET .
    echo "Pushing $ORG/$BASE-$TARGET to Docker Hub"
    $DP $ORG/$BASE-$TARGET
    echo "************ $TARGET done *************"
done

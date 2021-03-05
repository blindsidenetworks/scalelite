# Makefile to create docker images and package them
#
# 2021-03-05: Georg Lehner <gl@x-net.at>
#

VENDOR=x-net
REPO=scalelite
VERSION=v1
IMAGES=api nginx poller recording-importer

# No user servicable parts inside

TAGS=$(IMAGES:%=$(VENDOR)/$(REPO):$(VERSION)-%)

TGZS=$(IMAGES:%=$(REPO)-%.tar.gz)

help:
	@echo make tgz .. make target docker images and package them:
	@echo "     $(TGZS)"
	@echo make clean .. remove artefacts and the target docker images:
	@echo "     $(TAGS)"
	@echo
	@echo current images:
	@docker image ls $(VENDOR)/$(REPO)
.PHONY: help

tgz: $(TGZS)
.PHONY: tgz

$(IMAGES): Dockerfile
	docker build -t $(VENDOR)/$(REPO):$(VERSION)-$@ --target $@ .
.PHONY: $(IMAGES)

$(REPO)-%.tar.gz: %
	docker image save $(VENDOR)/$(REPO):$(VERSION)-$< | gzip > $@

clean:
	rm -f $(TGZS)
	-docker image rm $(TAGS)
.PHONY: clean

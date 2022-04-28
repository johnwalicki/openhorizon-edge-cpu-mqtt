# PSUtil service that sends the CPU output to Watson IoT Platform via MQTT

DOCKERHUB_ID:=
SERVICE_NAME:="cpu-mqtt-example-<yourname>"
SERVICE_VERSION:="1.0.0"
ARCH:="amd64"

# Leave blank for open DockerHub containers
# CONTAINER_CREDS:=-r "registry.wherever.com:myid:mypw"
CONTAINER_CREDS:=

default: build run

build:
	docker build -t $(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION) .
	docker image prune --filter label=stage=builder --force

dev: stop build
	docker run -it --name ${SERVICE_NAME} \
          $(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION) /bin/bash

run: stop
	docker run -d \
          --name ${SERVICE_NAME} \
          --env-file secrets/env.list \
          $(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION)

push:
	docker push $(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION)

publish-service:
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(SERVICE_NAME)" \
        SERVICE_VERSION="$(SERVICE_VERSION)"\
        SERVICE_CONTAINER="$(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION)" \
        echo hzn exchange service publish -O $(CONTAINER_CREDS) -f service.json --pull-image
	@ARCH=$(ARCH) \
        SERVICE_NAME="$(SERVICE_NAME)" \
        SERVICE_VERSION="$(SERVICE_VERSION)"\
        SERVICE_CONTAINER="$(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION)" \
	hzn exchange service publish -O $(CONTAINER_CREDS) -f service.json --pull-image

publish-policy:
	@ARCH=$(ARCH) \
        DOCKERHUB_ID="$(DOCKERHUB_ID)" \
        SERVICE_NAME="$(SERVICE_NAME)" \
        SERVICE_VERSION="$(SERVICE_VERSION)" \
	hzn exchange deployment addpolicy -f deployment-policy-mqtt.json ${HZN_ORG_ID}/policy-${SERVICE_NAME}_${ARCH}_${SERVICE_VERSION}

agent-run:
	@DOCKERHUB_ID="$(DOCKERHUB_ID)" \
	hzn register --policy node-policy.json

agent-stop:
	hzn unregister -f

stop:
	@docker rm -f ${SERVICE_NAME} >/dev/null 2>&1 || :

clean:
	@docker rmi -f $(DOCKERHUB_ID)/$(SERVICE_NAME):$(SERVICE_VERSION) >/dev/null 2>&1 || :

.PHONY: build dev run push publish-service publish-pattern stop clean

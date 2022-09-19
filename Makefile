# PSUtil service that sends the CPU output to Watson IoT Platform via MQTT

DOCKERHUB_ID:=docker.io/walicki
export SERVICE_NAME ?= "cpu-mqtt-example-instructor"
export SERVICE_VERSION ?= 1.1
export SERVICE_ORG_ID ?= $(HZN_ORG_ID)

export CONTAINER_IMAGE_BASE ?= $(DOCKERHUB_ID)/$(SERVICE_NAME)
export CONTAINER_IMAGE_VERSION ?= $(SERVICE_VERSION)

# Leave blank for open DockerHub containers
# CONTAINER_CREDS:=-r "registry.wherever.com:myid:mypw"
# CONTAINER_CREDS:=-r "us.icr.io:iamapikey:$(IAMAPIKEY)"

default: build run

build:
	@docker build --platform linux/arm64 -t $(CONTAINER_IMAGE_BASE)_arm64:$(CONTAINER_IMAGE_VERSION) -f ./Dockerfile
	@docker build --platform linux/amd64 -t $(CONTAINER_IMAGE_BASE)_amd64:$(CONTAINER_IMAGE_VERSION) -f ./Dockerfile
	docker image prune --filter label=stage=builder --force

dev: stop build
	docker run -it --name ${SERVICE_NAME} \
          $(CONTAINER_IMAGE_BASE)_amd64:$(CONTAINER_IMAGE_VERSION) /bin/bash

run: stop
	docker run -d \
          --name ${SERVICE_NAME} \
          --env-file secrets/env.list \
          $(CONTAINER_IMAGE_BASE)_amd64:$(CONTAINER_IMAGE_VERSION)

push:
	docker push $(CONTAINER_IMAGE_BASE)_arm64:$(SERVICE_VERSION)
	docker push $(CONTAINER_IMAGE_BASE)_amd64:$(SERVICE_VERSION)

publish-service:
	@echo "=================="
	@echo "PUBLISHING SERVICE"
	@echo "=================="
	@ARCH=arm64 \
        SERVICE_NAME="$(SERVICE_NAME)" \
        SERVICE_VERSION="$(SERVICE_VERSION)"\
								SERVICE_CONTAINER="$(CONTAINER_IMAGE_BASE)_arm64:$(CONTAINER_IMAGE_VERSION)" \
 hzn exchange service publish -O $(CONTAINER_CREDS) -f service.json --dont-change-image-tag
	@ARCH=amd64 \
        SERVICE_NAME="$(SERVICE_NAME)" \
        SERVICE_VERSION="$(SERVICE_VERSION)"\
								SERVICE_CONTAINER="$(CONTAINER_IMAGE_BASE)_amd64:$(CONTAINER_IMAGE_VERSION)" \
	hzn exchange service publish -O $(CONTAINER_CREDS) -f service.json --dont-change-image-tag

publish-policy:
	@ARCH=arm64 \
         SERVICE_NAME="$(SERVICE_NAME)" \
         SERVICE_VERSION="$(SERVICE_VERSION)" \
	 hzn exchange deployment addpolicy -f deployment-policy-mqtt.json ${HZN_ORG_ID}/policy-${SERVICE_NAME}_arm64_${SERVICE_VERSION}
	echo hzn exchange deployment addpolicy -f deployment-policy-mqtt.json ${HZN_ORG_ID}/policy-${SERVICE_NAME}_arm64_${SERVICE_VERSION}
	@ARCH=amd64 \
         SERVICE_NAME="$(SERVICE_NAME)" \
         SERVICE_VERSION="$(SERVICE_VERSION)" \
	 hzn exchange deployment addpolicy -f deployment-policy-mqtt.json ${HZN_ORG_ID}/policy-${SERVICE_NAME}_amd64_${SERVICE_VERSION}
	echo hzn exchange deployment addpolicy -f deployment-policy-mqtt.json ${HZN_ORG_ID}/policy-${SERVICE_NAME}_amd64_${SERVICE_VERSION}

agent-run:
	@DOCKERHUB_ID="$(DOCKERHUB_ID)" \
	hzn register --policy node-policy.json

agent-stop:
	hzn unregister -f

stop:
	@docker rm -f ${SERVICE_NAME} >/dev/null 2>&1 || :

clean:
	-docker rmi $(CONTAINER_IMAGE_BASE)_arm64:$(CONTAINER_IMAGE_VERSION) 2> /dev/null || :
	-docker rmi $(CONTAINER_IMAGE_BASE)_amd64:$(CONTAINER_IMAGE_VERSION) 2> /dev/null || :
	@docker image prune --filter label=stage=builder --force

.PHONY: build dev run push publish-service publish-policy stop clean

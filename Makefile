# if not run in travis, get docker_login and _pwd from file
ifndef TRAVIS
	docker_repo := zokradonh
	docker_login := `cat ~/.docker-account-user`
	docker_pwd := `cat ~/.docker-account-pwd`
endif

base_download_version := $(shell ./version.sh core)
core_download_version := $(shell ./version.sh core)
webapp_download_version := $(shell ./version.sh webapp)
zpush_download_version := $(shell ./version.sh zpush)

KOPANO_CORE_REPOSITORY_URL := file:/kopano/repo/core
KOPANO_WEBAPP_REPOSITORY_URL := file:/kopano/repo/webapp
KOPANO_WEBAPP_FILES_REPOSITORY_URL := file:/kopano/repo/files
KOPANO_WEBAPP_MDM_REPOSITORY_URL := file:/kopano/repo/mdm
KOPANO_WEBAPP_SMIME_REPOSITORY_URL := file:/kopano/repo/smime
KOPANO_ZPUSH_REPOSITORY_URL := http://repo.z-hub.io/z-push:/final/Debian_9.0/
RELEASE_KEY_DOWNLOAD := 0
DOWNLOAD_COMMUNITY_PACKAGES := 1

COMPOSE_FILE := docker-compose.yml-example
-include .env
export

# convert lowercase componentname to uppercase
COMPONENT = $(shell echo $(component) | tr a-z A-Z)

build-all: build-ssl build-base build-core build-utils build-webapp build-zpush build-web build-konnect build-playground build-ldap-demo

.PHONY: build
build: component ?= base
build:
	docker build \
		--build-arg docker_repo=${docker_repo} \
		--build-arg KOPANO_CORE_VERSION=${core_download_version} \
		--build-arg KOPANO_$(COMPONENT)_VERSION=${$(component)_download_version} \
		--build-arg KOPANO_CORE_REPOSITORY_URL=$(KOPANO_CORE_REPOSITORY_URL) \
		--build-arg KOPANO_WEBAPP_REPOSITORY_URL=$(KOPANO_WEBAPP_REPOSITORY_URL) \
		--build-arg KOPANO_WEBAPP_FILES_REPOSITORY_URL=$(KOPANO_WEBAPP_FILES_REPOSITORY_URL) \
		--build-arg KOPANO_WEBAPP_MDM_REPOSITORY_URL=$(KOPANO_WEBAPP_MDM_REPOSITORY_URL) \
		--build-arg KOPANO_WEBAPP_SMIME_REPOSITORY_URL=$(KOPANO_WEBAPP_SMIME_REPOSITORY_URL) \
		--build-arg KOPANO_ZPUSH_REPOSITORY_URL=$(KOPANO_ZPUSH_REPOSITORY_URL) \
		--build-arg RELEASE_KEY_DOWNLOAD=$(RELEASE_KEY_DOWNLOAD) \
		--build-arg DOWNLOAD_COMMUNITY_PACKAGES=$(DOWNLOAD_COMMUNITY_PACKAGES) \
		--build-arg ADDITIONAL_KOPANO_PACKAGES="$(ADDITIONAL_KOPANO_PACKAGES)" \
		--build-arg ADDITIONAL_KOPANO_WEBAPP_PLUGINS="$(ADDITIONAL_KOPANO_WEBAPP_PLUGINS)" \
		-t $(docker_repo)/kopano_$(component) $(component)/

build-base:
	component=base make build

build-core:
	component=core make build

build-utils:
	component=utils make build

build-webapp:
	component=webapp make build

build-zpush:
	component=zpush make build

build-ssl:
	docker build -t $(docker_repo)/kopano_ssl ssl/

build-web:
	docker build -t $(docker_repo)/kopano_web web/

build-konnect:
	docker build -t $(docker_repo)/kopano_konnect konnect/

build-playground:
	docker build -t $(docker_repo)/kopano_playground playground/

build-ldap-demo:
	docker build -t $(docker_repo)/kopano_ldap_demo ldap-demo/

tag-container: component ?= base
tag-container:
	@echo 'create tag $($(component)_version)'
	docker tag $(docker_repo)/kopano_$(component) $(docker_repo)/kopano_$(component):${$(component)_version}
	@echo 'create tag latest'
	docker tag $(docker_repo)/kopano_$(component) $(docker_repo)/kopano_$(component):latest
	git commit -m 'ci: committing changes for $(component)' -- $(component) || true
	git tag $(component)/${$(component)_version} || true

tag-base:
	$(eval base_version := \
	$(shell docker run --rm $(docker_repo)/kopano_base cat /kopano/buildversion))
	component=base make tag-container

tag-core:
	$(eval core_version := \
	$(shell docker run --rm $(docker_repo)/kopano_core cat /kopano/buildversion | cut -d- -f2))
	component=core make tag-container

tag-utils:
	$(eval utils_version := \
	$(shell docker run --rm $(docker_repo)/kopano_utils cat /kopano/buildversion | cut -d- -f2))
	component=utils make tag-container

tag-webapp:
	$(eval webapp_version := \
	$(shell docker run --rm $(docker_repo)/kopano_webapp cat /kopano/buildversion | grep webapp | cut -d- -f2 | cut -d+ -f1))
	component=webapp make tag-container

tag-zpush:
	$(eval zpush_version := \
	$(shell docker run --rm $(docker_repo)/kopano_zpush cat /kopano/buildversion | tail -n 1 | grep -o -P '(?<=-).*(?=\+)'))
	component=zpush make tag-container

tag-web:
	$(eval web_version := \
	$(shell docker run --rm $(docker_repo)/kopano_web env | grep CODE_VERSION | cut -d'=' -f2))
	component=web make tag-container

tag-konnect:
	$(eval konnect_version := \
	$(shell docker run --rm $(docker_repo)/kopano_konnect env | grep CODE_VERSION | cut -d'=' -f2))
	component=konnect make tag-container


# Docker publish
repo-login:
	@docker login -u $(docker_login) -p $(docker_pwd)

publish: repo-login publish-ssl publish-base publish-core publish-utils publish-webapp publish-zpush publish-ssl publish-web publish-konnect publish-playground

publish-container: component ?= base
publish-container:
	@echo 'publish latest to $(docker_repo)/kopano_$(component)'
	docker push $(docker_repo)/kopano_$(component):${$(component)_version}
	docker push $(docker_repo)/kopano_$(component):latest

publish-base: build-base tag-base
	component=base make publish-container

publish-core: build-core tag-core
	component=core make publish-container

publish-utils: build-core build-utils tag-utils
	component=utils make publish-container

publish-webapp: build-webapp tag-webapp
	component=webapp make publish-container

publish-zpush: build-zpush tag-zpush
	component=zpush make publish-container

publish-ssl: build-ssl
	docker push $(docker_repo)/kopano_ssl:latest

publish-web: build-web tag-web
	docker push $(docker_repo)/kopano_web:latest

publish-konnect: build-konnect tag-konnect
	component=konnect make publish-container

publish-playground: build-playground
	docker push $(docker_repo)/kopano_playground:latest

test:
	docker-compose -f $(COMPOSE_FILE) down -v || true
	make build-all
	docker-compose -f $(COMPOSE_FILE) build
	docker-compose -f $(COMPOSE_FILE) up -d
	docker-compose -f $(COMPOSE_FILE) ps

test-quick:
	docker-compose -f $(COMPOSE_FILE) stop || true
	docker-compose -f $(COMPOSE_FILE) up -d
	docker-compose -f $(COMPOSE_FILE) ps

test-stop:
	docker-compose -f $(COMPOSE_FILE) stop || true

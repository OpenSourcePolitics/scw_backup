DRY_RUN := false
VERBOSE := false
TAG := "backup"
BACKUP_RETENTION := 3

build:
	docker build -t scw_backup . 

run: 
	docker run -e ACCESS_KEY=${ACCESS_KEY} -e SECRET_KEY=${SECRET_KEY} -e ORGANIZATION_ID=${ORGANIZATION_ID} -e DEFAULT_PROJECT_ID=${DEFAULT_PROJECT_ID} -e VERBOSE=${VERBOSE} -e DRY_RUN=${DRY_RUN} -e TAG=${TAG} -e BACKUP_RETENTION=${BACKUP_RETENTION} -e ROCKET_USER_ID=${ROCKET_USER_ID} -e ROCKET_SECRET_TOKEN=${ROCKET_SECRET_TOKEN} scw_backup:latest

test:
	@make build
	@make run

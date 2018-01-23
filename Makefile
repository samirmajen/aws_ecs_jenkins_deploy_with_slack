SHELL=/bin/sh
NAME=MyApp
VERSION=$(shell git rev-parse HEAD)
ECR=myapp-ecr-repo.amazonaws.com
CURRENT_WORKING_DIR=$(shell pwd)
GIT_LOG=$(shell git log -1)
AWS_LOGIN=$(shell aws ecr get-login --no-include-email --region eu-west-1)
AWS_REGION=eu-west-1
CLUSTER_NAME=
SERVICE_NAME=

build:
	echo "Building $(GIT_LOG) for version: $(VERSION) in $(CURRENT_WORKING_DIR)"
	docker build -t $(NAME) .
	
run:
	echo "Running $(NAME)s for version: $(VERSION)"
	docker run -tid $(NAME):latest --name $(NAME)

test:
	echo "Running tests for version: $(VERSION)"
	# create runtime build directory for junit and bdd xml files
	$(shell mkdir -p build/junit && mkdir build/bdd  && mkdir build/coverage && chown -R jenkins:jenkins build)
	# run $(NAME) and tests output xml into new build dir
	docker exec ...

archive:
	# copy artifacts from docker $(NAME) (running on slave) to slave so they can be available in jenkins reports
	docker cp $(NAME):/dir/to/artifacts .

clean:
	# this section is always run, it attempts to stop all containers (some may not run if something failed so || is used to not break the clean up phase)
	# stop containers
	echo "Cleaning up version: $(VERSION) in $(CURRENT_WORKING_DIR)"
	echo "Stopping containers"
	@docker stop $(NAME) || echo "Could not stop container $(NAME)"
	# remove $(NAME)s
	echo "Removing containers"
	@docker rm $(NAME) || echo "Could not remove container $(NAME)"
	# delete all images to save diskspace
	echo "Removing Images"
	@docker rmi IMAGE || echo "Could not remove image $(NAME)"

push:
	# push build to AWS ECR
	echo "Pushing Image to ECR $(ECR)"
	# login to AWS to enable push
	@$(AWS_LOGIN)
	# tag this build with the git revision number for traceability
	docker tag $(NAME):latest $(ECR)/$(NAME):$(VERSION)
	# push to AWS
	docker push $(ECR)/$(NAME):$(VERSION)
	
deploy:
	# deploy to AWS ECS using aws cli and jq to format and extract json data
	echo "Deploying $(ECR_DEPLOY_ENVIRONMENT)"
	# get current deployed service task definiion incase a rollback needs to take place
	aws ecs describe-services --region $(AWS_REGION) --services $(SERVICE_NAME) --cluster $(CLUSTER_NAME) | jq -r .services[0].taskDefinition
	# get current deployed $(NAME) definition task, replace image(s) with new version and tag for all $(NAME)s that need it
	aws --output json ecs describe-task-definition --task-definition $(SERVICE_NAME) --region $(AWS_REGION) | jq '.taskDefinition.$(NAME)Definitions' | sed -r 's/(.amazonaws.com\/:)(staging|master|testing)(\-)([a-zA-Z0-9]+)/\1$(VERSION)/g' | tee /tmp/cluster_definition__$(VERSION)
	# get family and volume definitions
	aws --output json ecs describe-task-definition --task-definition $(SERVICE_NAME) --region $(AWS_REGION) | jq '.taskDefinition.family' | tee /tmp/family__$(VERSION)
	aws --output json ecs describe-task-definition --task-definition $(SERVICE_NAME) --region $(AWS_REGION) | jq '.taskDefinition.volumes' | tee /tmp/volumes__$(VERSION)
	# create new task definition
	echo "{\"$(NAME)Definitions\":$$(cat /tmp/cluster_definition__$(VERSION)),\"family\":$$(cat /tmp/family__$(VERSION)),\"volumes\":$$(cat /tmp/volumes__$(VERSION))}" > /tmp/new_ecs_task_definition__$(VERSION)
	# register new task and get new revision number
	aws --output json ecs register-task-definition --region $(AWS_REGION) --family $(SERVICE_NAME) --cli-input-json file:///tmp/new_ecs_task_definition__$(VERSION) | jq '.taskDefinition.taskDefinitionArn' | tee /tmp/new_task_version__$(VERSION)
	# get task definition revision number and update service to use new task revision - all run on one line (in one shell)
	export TASK_REV__$(VERSION)=$$(cat /tmp/new_task_version__$(VERSION) | tr "/" " " | awk '{print $$2}' | sed 's/"$$//'); \
	aws ecs update-service --region $(AWS_REGION) --cluster $(CLUSTER_NAME) --service $(SERVICE_NAME) --task-definition "$$TASK_REV__$(VERSION)"
	# cleanup
	rm -f /tmp/new_ecs_task_definition__$(VERSION) /tmp/cluster_definition__$(VERSION) /tmp/family__$(VERSION) /tmp/volumes__$(VERSION) /tmp/new_task_version__$(VERSION)

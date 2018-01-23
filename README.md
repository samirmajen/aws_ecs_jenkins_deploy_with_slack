# aws_ecs_jenkins_deploy_with_slack
Simple makefile and jenkins pipeline which deploys to AWS ECS via ECR. This can be used when running Jenkins in AWS ECS as a task and trying to auto deploy using a slave which is also running as an ECS task.

This forms part of a CI/CD process which auto deploys the staging branch to a staging environment and uses a one-click deploy to production by requesting for approval. Approval appears in jenkins to the users listed in the submitter comma separated list.

- This pipeline integrates with slack to send automated notifications as each build runs.
- This pipeline assumes you have exposed the docker sock from the ECS host to the jenkins slave
- These scripts assume you have the following packages installed on the slave running the builds
  - awscli
  - jq
  - git
  - docker

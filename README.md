# aws_ecs_jenkins_deploy_with_slack
Simple makefile and jenkins pipeline which deploys to AWS ECS via ECR. This can be used when running Jenkins in AWS ECS as a task and trying to auto deploy using a slave which is also running as an ECS task.

- This pipeline integrates with slack to send automated notifications as each build runs.
- This pipeline assumes you have exposed the docker sock from the ECS host to the jenkins slave
- These scripts assume you have the following packages installed on the slave running the builds
  - awscli
  - jq
  - git
  - docker

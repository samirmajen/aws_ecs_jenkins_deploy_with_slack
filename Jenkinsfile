def userInput

pipeline {
    agent { label 'ecs_3_14-1' }
    options {
        timeout(time: 15, unit: 'MINUTES')
    }
    stages {
        stage('Setup') {
            steps {
                script {
                    env.GIT_COMMIT_DETAILS = sh(returnStdout: true, script: 'git log -1 --name-status').trim()
                }
                slackSend (color: 'good', message: "Starting Pipeline (branch *${env.BRANCH_NAME}*)")
                slackSend (color: 'good', message: "Building ${env.GIT_COMMIT_DETAILS} \non branch *${env.BRANCH_NAME}*")
            }
        }
        stage('Build') {
            steps {
                slackSend (color: 'good', message: "Starting Build Stage (branch *${env.BRANCH_NAME}*)")
                sh 'make build'
            }
        }
        stage('Run') {
            steps {
                slackSend (color: 'good', message: "Running Containers (branch *${env.BRANCH_NAME}*)")
                sh 'make run'
            }
        }
        stage('Test') {
            steps {
                slackSend (color: 'good', message: "Running Tests (branch *${env.BRANCH_NAME}*)")
                sh 'make test'
            }
        }
        stage('Archive') {
            steps {
                slackSend (color: 'good', message: "Archiving Test report data (branch *${env.BRANCH_NAME}*)")
                sh 'make archive'
            }
        }
        stage('Report') {
            steps {
               junit 'build/**/*.xml'
                publishHTML(target: [
                    reportName : 'Coverage',
                    reportDir:   'build/coverage',
                    reportFiles: 'index.html',
                    keepAll:     true,
                    alwaysLinkToLastBuild: true,
                    allowMissing: false
                ])
           }
        }
        stage('Push') {
            when { expression { env.BRANCH_NAME =~ /(jenkins|staging|master)/ } }
            steps {
                slackSend (color: 'good', message: "Pushing new image to ECR Repository (branch *${env.BRANCH_NAME}*)")
                script {
                    sh "make push"
                }
            }
        }
        stage('DeployStaging') {
            when { expression { env.BRANCH_NAME =~ /(jenkins|staging)/ } }
            steps {
                slackSend (color: 'good', message: "Deploying new image to ECR Repository (branch *${env.BRANCH_NAME}*)")

                script {
                    if (env.BRANCH_NAME == 'staging') {
                        sh "make deploy"
                        slackSend (color: 'good', message: "Build successfully deployed (branch *${env.BRANCH_NAME}*)")
                    } else {
                        slackSend (color: 'good', message: "Skipping deployment of (branch *${env.BRANCH_NAME}*)")
                    }
                }
            }
        }
        stage('AskDeploy') {
            when { expression { env.BRANCH_NAME == 'master' } }
            steps {
                slackSend (color: 'good', message: "Deploying image to ECR Repository (branch *${env.BRANCH_NAME}*)")
                slackSend (color: 'good', message: "*Please login to Jenkins and approve this deployment request* ${env.BUILD_URL} (branch *${env.BRANCH_NAME}*)")
                
                timeout(time: 10, unit: 'MINUTES') {
                  script {
                      userInput = input(
                          message: 'Do you want to deploy this build to production?', 
                          submitter: 'username1,username2',
                          submitterParameter: 'APPROVER'
                      )
                  }
                }
            }
        }
        stage('DeployProduction') {
            when { expression { env.BRANCH_NAME == 'master' } }
            steps {
                script {
                    slackSend (color: 'warning', message: "Deployment *approved* by *${userInput}* (branch *${env.BRANCH_NAME}*)")
                        
                    sh "make deploy"

                    slackSend (color: 'good', message: "Build successfully deployed (branch *${env.BRANCH_NAME}*)")
                }
            } 
        }
    }

    post {
        always {
            sh "make clean"
        }
        success {
            slackSend (color: 'good', message: "Pipeline Passed (branch *${env.BRANCH_NAME}*) :thumbsup:")
        }
        failure {
            slackSend (color: 'danger', message: "Pipeline Failed (branch *${env.BRANCH_NAME}*) :thumbsdown:")
        }
        unstable {
            slackSend (color: 'warning', message: "Pipeline Unstable (branch *${env.BRANCH_NAME}*) :confused:")
        }
        //changed {
        //    echo 'This will run only if the state of the Pipeline has changed'
        //    echo 'For example, if the Pipeline was previously failing but is now successful'
        //}
    }
}

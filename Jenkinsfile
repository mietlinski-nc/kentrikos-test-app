#!groovy

library 'kentrikos-shared-library'

def app_address = ""

pipeline {
    options {
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        K8S_FLAVOR = 'kops'
        REPO_URL = 'https://github.com/radepal/kentrikos-test-app.git'
        APP_NAME = 'kentrikos-hello-app'
        ECR_REPO_NAME = "$PRODUCT_DOMAIN_NAME-$ENVIRONMENT_TYPE/$APP_NAME"
        ECR_REPO = "$AWS_OPERATIONS_ACCOUNT_NUMBER" + ".dkr.ecr." + "$AWS_REGION" + ".amazonaws.com/$ECR_REPO_NAME"
        CONFIG_DIR = "operations/$AWS_REGION/env-$K8S_FLAVOR"
    }
    agent any
    stages {
        stage('Git clone') {
            steps {
                gitCloneAppRepo repo: "$REPO_URL"
            }
        }

        stage('Create ECR') {
            steps {
                ecrCreateRepository repo_name: "$ECR_REPO_NAME"
            }
        }
        stage('Docker Build') {
            steps {
                withProxyEnv() {
                    sh 'docker build -t $APP_NAME:latest .'
                }
            }
        }
        stage('Docker Tag') {
            steps {
                withProxyEnv() {
                    sh 'docker tag $APP_NAME $ECR_REPO'

                }
            }
        }
        stage('Docker Push') {
            steps {
                withProxyEnv() {
                    sh 'eval $(aws ecr get-login --no-include-email --region $AWS_REGION | sed "s|https://||")'
                    sh 'docker push  $ECR_REPO'
                }
            }
        }
        stage('Switch K8S context') {
            steps {
                kubectlSwitchContextOps()
            }
        }

        stage('Create $PRODUCT_DOMAIN_NAME namespace') {
            steps {
                withProxyEnv() {
                    script {
                        sh '''
                                    #!/bin/bash -x
                                    if ! kubectl get namespace $PRODUCT_DOMAIN_NAME;
                                    then
                                        echo "Namespace for $PRODUCT_DOMAIN_NAME does not exist, creating..."
                                        kubectl create namespace $PRODUCT_DOMAIN_NAME
                                    fi
                                    '''
                    }
                }
            }
        }
        stage('Get Domain name') {
            steps {
                ws("${env.JOB_NAME}-config") {
                    gitCloneConfigRepo()
                    dir("$CONFIG_DIR") {
                        withProxyEnv() {
                            script {
                                def jenkins_parameters = readYaml file: 'jenkins/parameters.yaml'
                                println "Getting domain name"
                                def r53DomainName = sh(script: "aws route53 get-hosted-zone --id " + jenkins_parameters.domainHostedZoneID + " --output text --query 'HostedZone.Name'",
                                        returnStdout: true).trim().replaceAll("\\.\$", "")
                                app_address = "$APP_NAME." + jenkins_parameters.domainAliasPrefix + "." + r53DomainName
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy application') {
            steps {
                withProxyEnv() {
                    script {
                        sh """
                           #!/bin/bash
                           helm upgrade --install --wait --set image.repository=$ECR_REPO  --set=ingress.enabled=true,ingress.hosts={$app_address} --namespace $PRODUCT_DOMAIN_NAME $APP_NAME helm/
                         """
                    }
                }
            }
        }
    }
}

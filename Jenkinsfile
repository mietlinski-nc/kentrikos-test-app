#!groovy

library 'kentrikos-shared-library'

pipeline {
    options {
        timeout(time: 60, unit: 'MINUTES')
    }
    environment {
        K8S_FLAVOR = 'env-kops'
        REPO_URL = 'https://github.com/radepal/kentrikos-test-app.git'
        APP_NAME = 'kentrikos-hello-app'
        ECR_REPO_NAME = "$PRODUCT_DOMAIN_NAME-$ENVIRONMENT_TYPE/$APP_NAME"
        ECR_REPO = "$AWS_OPERATIONS_ACCOUNT_NUMBER" + ".dkr.ecr." + "$AWS_REGION" + ".amazonaws.com/$ECR_REPO_NAME"
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
        stage('Switch K8S context'){
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
        stage('Deploy application') {
                    steps {

                            withProxyEnv() {
                                    script {

                                        sh """
                                        #!/bin/bash
                                        helm upgrade --install --wait --set image.repository=$ECR_REPO  --namespace $PRODUCT_DOMAIN_NAME helm/
                                        """
                                    }
                                }

                    }
        }
    }
}

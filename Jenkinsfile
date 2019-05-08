#!groovy

library 'kentrikos-shared-library'

def app_address = ""

pipeline {
    options {
        timeout(time: 60, unit: 'MINUTES')
    }

    environment {
        K8S_FLAVOR = 'eks'
        REPO_URL = 'https://github.com/mietlinski-nc/kentrikos-test-app.git'
        APP_NAME = 'kentrikos-hello-app-mm'
        ECR_REPO_NAME = "$PRODUCT_DOMAIN_NAME-$ENVIRONMENT_TYPE/$APP_NAME"
        ECR_REPO = "$AWS_OPERATIONS_ACCOUNT_NUMBER" + ".dkr.ecr." + "$AWS_REGION" + ".amazonaws.com/$ECR_REPO_NAME"
        CONFIG_DIR = "application/$AWS_REGION/env-$K8S_FLAVOR"
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

        stage('Grant Cross-Account access to ECR') {
             steps {
                 withProxyEnv() {
                     script {
                         def ecrPolicyJSON = """
                         {
                             "Version": "2012-10-17",
                             "Statement": [
                                 {
                                     "Sid": "AllowPull",
                                     "Effect": "Allow",
                                     "Action": [
                                         "ecr:BatchGetImage",
                                         "ecr:GetDownloadUrlForLayer"
                                     ],
                                     "Principal": {
                                         "AWS": ["arn:aws:iam::${AWS_APPLICATION_ACCOUNT_NUMBER}:root"]
                                     }
                                 }
                             ]
                         }
                         """
                         writeFile file: 'ecr_policy.json', text: ecrPolicyJSON

                         sh(script: "aws ecr get-repository-policy --region ${AWS_REGION} --repository-name ${ECR_REPO_NAME} || aws ecr set-repository-policy --region ${AWS_REGION} --repository-name ${ECR_REPO_NAME} --policy-text \"\$(cat ecr_policy.json)\"", returnStdout: true)
                     }
                 }
             }
         }

        stage('Switch K8S context') {
            steps {
                kubectlSwitchContextApp()
            }
        }

        stage('Create $PRODUCT_DOMAIN_NAME namespace') {
            steps {
                withProxyEnv() {
                withAWS(role: "$CROSS_ACCOUNT_ROLE_NAME", roleAccount: "$AWS_APPLICATION_ACCOUNT_NUMBER") {
                    script {
                        sh '''
                                    #!/bin/bash -x
                                    if ! kubectl get namespace $PRODUCT_DOMAIN_NAME;
                                    then
                                        echo "Namespace for $PRODUCT_DOMAIN_NAME does not exist, creating..."
                                        kubectl create namespace $PRODUCT_DOMAIN_NAME
                                    fi
                                    '''
                    }}
                }
            }
        }

        stage('Deploy application') {
            steps {
                withProxyEnv() {
                withAWS(role: "$CROSS_ACCOUNT_ROLE_NAME", roleAccount: "$AWS_APPLICATION_ACCOUNT_NUMBER") {
                    script {
                        sh """
                           #!/bin/bash
                           helm delete --purge $APP_NAME helm/
                           helm upgrade --install --wait --set image.repository=$ECR_REPO  --set=ingress.enabled=true --namespace $PRODUCT_DOMAIN_NAME $APP_NAME helm/
                         """
                    }}
                }
            }
        }
    }
}

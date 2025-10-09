pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        ECR_REPOSITORY = 'game-app'
        CLUSTER_NAME = 'game-cluster'
        SERVICE_NAME = 'game-service'
        TERRAFORM_DIR = 'terraform'
        DOCKER_IMAGE_TAG = "${env.BUILD_ID}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Nayannyk/Game.git'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    withCredentials([usernamePassword(credentialsId: 'docker_user', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                        sh """
                            docker build -t ${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG} .
                            docker tag ${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG} ${ECR_REPOSITORY}:latest
                        """
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withCredentials([[
                        $class: 'AmazonWebServicesCredentialsBinding',
                        credentialsId: 'aws-creds',
                        accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                        secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                    ]]) {
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                            docker tag ${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG}
                            docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${DOCKER_IMAGE_TAG}
                        """
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir(TERRAFORM_DIR) {
                    script {
                        withCredentials([[
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-creds',
                            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                        ]]) {
                            sh """
                                terraform init
                                terraform plan -var="ecr_image_tag=${DOCKER_IMAGE_TAG}" -var="aws_region=${AWS_REGION}" -var="ecr_repository=${ECR_REPOSITORY}"
                                terraform apply -var="ecr_image_tag=${DOCKER_IMAGE_TAG}" -var="aws_region=${AWS_REGION}" -var="ecr_repository=${ECR_REPOSITORY}" -auto-approve
                            """
                        }
                    }
                }
            }
        }
        
        stage('Get Load Balancer DNS') {
            steps {
                dir(TERRAFORM_DIR) {
                    script {
                        sh """
                            terraform output load_balancer_dns > ../lb_dns.txt
                        """
                        lb_dns = readFile('../lb_dns.txt').trim()
                        echo "Application URL: http://${lb_dns}/game.html"
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh 'rm -f lb_dns.txt || true'
        }
        success {
            script {
                lb_dns = sh(script: "cd ${TERRAFORM_DIR} && terraform output load_balancer_dns", returnStdout: true).trim()
                echo "🎉 Deployment Successful!"
                echo "🌐 Your game is accessible at: http://${lb_dns}/game.html"
            }
        }
    }
}

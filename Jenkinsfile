/*
 * ============================================================================
 * PIPELINE CI/CD - PAYMYBUDDY APPLICATION
 * ============================================================================
 * 
 * Cette pipeline implémente un flux complet de CI/CD pour déployer une 
 * application Spring Boot sur AWS EC2 via Docker.
 * 
 * Flux: GitLab → Jenkins → Tests → SonarCloud → Docker → AWS (Staging/Prod)
 * 
 * Auteur: Christelle (adalbert-code)
 * Formation: EAZYTraining DevOps BootCamp
 * ============================================================================
 */

pipeline {
    agent none
    
    environment {
        // DOCKER CONFIGURATION
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE = "adal2022/paymybuddy"
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // SONARCLOUD CONFIGURATION
        SONAR_TOKEN = credentials('sonarcloud-token')
        SONAR_PROJECT_KEY = "Adalbert-code_paymybuddy00"
        SONAR_ORG = "adalbert-code"
        
        // AWS EC2 CONFIGURATION
        STAGING_HOST = "98.94.13.26"
        PROD_HOST = "13.220.94.174"
        SSH_USER = "ubuntu"
        
        // SLACK NOTIFICATION
        SLACK_WEBHOOK = credentials('slack-webhook')
    }
    
    stages {
        
        stage('Checkout') {
            agent any
            steps {
                git branch: 'main', 
                    url: 'https://gitlab.com/Adalbert-code/paymybuddy00.git'
            }
        }
        
        stage('Tests Automatisés') {
            agent {
                docker {
                    image 'maven:3.9-amazoncorretto-17'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn clean test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        stage('Vérification Qualité du Code - SonarCloud') {
            agent {
                docker {
                    image 'maven:3.9-amazoncorretto-17'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            steps {
                sh """
                    mvn sonar:sonar \
                    -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                    -Dsonar.organization=${SONAR_ORG} \
                    -Dsonar.host.url=https://sonarcloud.io \
                    -Dsonar.login=${SONAR_TOKEN}
                """
            }
        }
        
        stage('Compilation et Packaging') {
            agent {
                docker {
                    image 'maven:3.9-amazoncorretto-17'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            steps {
                sh 'mvn clean package -DskipTests'
            }
            post {
                success {
                    archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
                }
            }
        }
        
        stage('Build et Push Docker Image') {
            agent any
            steps {
                script {
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    """
                    
                    sh """
                        echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    """
                }
            }
        }
        
        stage('Déploiement Production') {
            agent any
            steps {
                input message: 'Déployer en production?', ok: 'Déployer'
                
                sshagent(credentials: ['aws-ssh-prod']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${PROD_HOST} '
                            echo "Verification de MySQL..."
                            
                            if docker ps | grep -q mysql-prod; then
                                echo "MySQL deja en cours execution"
                            else
                                echo "Installation de MySQL..."
                                docker rm mysql-prod 2>/dev/null || true
                                
                                docker run -d \\
                                    --name mysql-prod \\
                                    -p 3306:3306 \\
                                    -e MYSQL_ROOT_PASSWORD=password \\
                                    -e MYSQL_DATABASE=db_paymybuddy \\
                                    --restart unless-stopped \\
                                    mysql:8.0
                                
                                echo "Attente du demarrage de MySQL (30 secondes)..."
                                sleep 30
                                echo "MySQL installe et demarre"
                            fi
                            
                            echo "Pull de l image Docker de l application..."
                            docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "Arret de l ancien container applicatif..."
                            docker stop paymybuddy-prod || true
                            
                            echo "Suppression de l ancien container..."
                            docker rm paymybuddy-prod || true
                            
                            echo "Lancement du nouveau container avec configuration MySQL..."
                            docker run -d --name paymybuddy-prod -p 8080:8080 \\
                                -e SPRING_DATASOURCE_URL=jdbc:mysql://172.17.0.1:3306/db_paymybuddy \\
                                -e SPRING_DATASOURCE_USERNAME=root \\
                                -e SPRING_DATASOURCE_PASSWORD=password \\
                                ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "Deploiement production termine!"
                        '
                    """
                }
            }
        }
        
        stage('Tests de Validation Production') {
            agent any
            steps {
                script {
                    sleep(time: 30, unit: 'SECONDS')
                    sh """
                        curl -f http://${PROD_HOST}:8080/actuator/health || exit 1
                    """
                }
            }
        }
    }
    
    post {
        always {
            node('') {
                script {
                    def status = currentBuild.result ?: 'SUCCESS'
                    def color = status == 'SUCCESS' ? 'good' : 'danger'
                    def emoji = status == 'SUCCESS' ? ':white_check_mark:' : ':x:'
                    
                    def message = """
                        ${emoji} *Pipeline ${status}*
                        Job: ${env.JOB_NAME}
                        Build: #${env.BUILD_NUMBER}
                        Duration: ${currentBuild.durationString}
                    """
                    
                    sh """
                        curl -X POST ${SLACK_WEBHOOK} \
                        -H 'Content-Type: application/json' \
                        -d '{
                            "attachments": [{
                                "color": "${color}",
                                "text": "${message}",
                                "footer": "Jenkins CI/CD Pipeline",
                                "ts": ${currentBuild.startTimeInMillis / 1000}
                            }]
                        }'
                    """
                }
            }
        }
        
        success {
            echo '✅ Pipeline exécutée avec succès!'
            echo '📦 Application déployée et validée'
        }
        
        failure {
            echo '❌ Pipeline échouée!'
            echo '🔍 Vérifiez les logs pour identifier le problème'
        }
    }
}

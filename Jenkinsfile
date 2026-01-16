// ============================================================================
// PIPELINE CI/CD PAYMYBUDDY - VERSION COMPLÈTE AVEC STAGING + GITFLOW
// ============================================================================
// 
// Description : Pipeline Jenkins pour automatiser les tests, l'analyse de code,
//               le build, et le déploiement de l'application PayMyBuddy
//
// Environnements :
//   - Staging (EC2 107.20.66.5 - branche main uniquement)
//   - Production (EC2 54.234.61.221 - branche main uniquement)
//   - Tests (H2 in-memory - toutes branches)
// 
// GitFlow :
//   - Branch main : Toutes les étapes (tests → staging → production)
//   - Autres branches : Tests, SonarCloud, Build uniquement
//
// Auteur : Adalbert Nanda (Christelle)
// Date : Décembre 2024
// ============================================================================

pipeline {
    agent any

    // ========================================================================
    // ENVIRONNEMENT : Variables globales
    // ========================================================================
    environment {
        // --- Docker Hub ---
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE = 'adal2022/paymybuddy'
        
        // --- SonarCloud ---
        SONAR_TOKEN = credentials('sonarcloud-token')
        SONAR_PROJECT_KEY = 'Adalbert-code_paymybuddy00'
        SONAR_ORGANIZATION = 'adalbert-code'
        
        // --- AWS EC2 Staging ---
        EC2_STAGING_IP = '107.20.66.5'
        EC2_STAGING_USER = 'ubuntu'

        // --- AWS EC2 Production ---
        EC2_PROD_IP = '54.234.61.221'
        EC2_PROD_USER = 'ubuntu'
        
        // --- Notifications ---
        SLACK_WEBHOOK = credentials('slack-webhook')
    }

    // ========================================================================
    // STAGES : Pipeline CI/CD
    // ========================================================================
    stages {
        
        // ====================================================================
        // STAGE 1 : CHECKOUT - Récupération du code (TOUTES BRANCHES)
        // ====================================================================
        stage('Checkout') {
            steps {
                echo "🔄 [${env.BRANCH_NAME}] Récupération du code source..."
                
                checkout scm
                
                echo "✅ Code source récupéré depuis la branche ${env.BRANCH_NAME}"
            }
        }

        // ====================================================================
        // STAGE 2 : TESTS AUTOMATISÉS (TOUTES BRANCHES)
        // ====================================================================
        stage('Tests Automatisés') {
            steps {
                echo "🧪 [${env.BRANCH_NAME}] Exécution des tests automatisés..."
                
                script {
                    docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2') {
                        sh 'mvn clean test'
                    }
                }
                
                echo '✅ Tests terminés avec succès'
            }
            
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                    echo '📊 Rapports de tests publiés'
                }
            }
        }

        // ====================================================================
        // STAGE 3 : VÉRIFICATION QUALITÉ DU CODE (TOUTES BRANCHES)
        // ====================================================================
        stage('Vérification Qualité du Code - SonarCloud') {
            steps {
                echo "🔍 [${env.BRANCH_NAME}] Analyse SonarCloud..."

                script {
                    docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2 --dns 8.8.8.8 --dns 8.8.4.4') {
                        sh """
                            mvn sonar:sonar \
                                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                                -Dsonar.organization=${SONAR_ORGANIZATION} \
                                -Dsonar.host.url=https://sonarcloud.io \
                                -Dsonar.login=\$SONAR_TOKEN
                        """
                    }
                }

                echo '✅ Analyse SonarCloud terminée'
            }
        }

        // ====================================================================
        // STAGE 4 : COMPILATION ET PACKAGING (TOUTES BRANCHES)
        // ====================================================================
        stage('Compilation et Packaging') {
            steps {
                echo "📦 [${env.BRANCH_NAME}] Compilation et packaging..."
                
                script {
                    docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2') {
                        sh 'mvn clean package -DskipTests'
                    }
                }
                
                echo '✅ Application packagée avec succès'
            }
            
            post {
                success {
                    archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
                }
            }
        }

        // ====================================================================
        // STAGE 5 : BUILD ET PUSH DOCKER IMAGE (TOUTES BRANCHES)
        // ====================================================================
        stage('Build et Push Docker Image') {
            steps {
                echo "🐳 Construction de l'image Docker..."
                
                script {
                    def buildNumber = env.BUILD_NUMBER
                    
                    // Détection robuste de la branche
                    // Priorité : BRANCH_NAME → GIT_BRANCH → fallback 'main'
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                    
                    // Nettoie 'origin/' si présent (GIT_BRANCH contient souvent 'origin/main')
                    branchName = branchName.replaceAll('origin/', '')
                    
                    // Remplace '/' par '-' pour un tag Docker valide
                    def branchTag = branchName.replaceAll('/', '-')
                    
                    echo "📌 Branch détectée: ${branchName}"
                    echo "🏷️  Tag Docker: ${branchTag}-${buildNumber}"
                    
                    // Build de l'image Docker avec tag de branche
                    sh "docker build -t ${DOCKER_IMAGE}:${branchTag}-${buildNumber} ."
                    
                    // Tag 'latest' uniquement pour la branche main
                    if (branchName == 'main') {
                        sh "docker tag ${DOCKER_IMAGE}:${branchTag}-${buildNumber} ${DOCKER_IMAGE}:latest"
                        echo "🏷️  Tag 'latest' ajouté"
                    }
                    
                    echo '✅ Image Docker construite'
                    
                    // Push sur Docker Hub
                    sh """
                        echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
                        docker push ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
                    """
                    
                    // Push 'latest' si branche main
                    if (branchName == 'main') {
                        sh "docker push ${DOCKER_IMAGE}:latest"
                        echo "✅ Image 'latest' pushée"
                    }
                    
                    sh "docker logout"
                    
                    echo "✅ Image Docker pushée : ${DOCKER_IMAGE}:${branchTag}-${buildNumber}"
                }
            }
        }

        // ====================================================================
        // STAGE 6 : DÉPLOIEMENT STAGING (BRANCHE MAIN UNIQUEMENT)
        // ====================================================================
        stage('Déploiement Staging') {
            when {
                expression {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    branchName = branchName.replaceAll('origin/', '')
                    return branchName == 'main'
                }
            }
            steps {
                echo '🚀 Déploiement en environnement de STAGING...'
                
                sshagent(['aws-ssh-staging']) {
                    script {
                        def buildNumber = env.BUILD_NUMBER
                        def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                        branchName = branchName.replaceAll('origin/', '')
                        def branchTag = branchName.replaceAll('/', '-')
                        
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_STAGING_USER}@${EC2_STAGING_IP} '
                                echo "=========================================="
                                echo "  DÉPLOIEMENT STAGING - Build #${buildNumber}"
                                echo "=========================================="
                                
                                # 1. Vérification MySQL
                                echo "📦 Vérification de MySQL..."
                                if docker ps | grep -q mysql-staging; then
                                    echo "✅ MySQL déjà en cours d execution"
                                else
                                    echo "📥 Installation de MySQL Staging..."
                                    docker rm mysql-staging 2>/dev/null || true
                                    
                                    docker run -d \\
                                        --name mysql-staging \\
                                        -p 3306:3306 \\
                                        -e MYSQL_ROOT_PASSWORD=password \\
                                        -e MYSQL_DATABASE=db_paymybuddy \\
                                        --restart unless-stopped \\
                                        mysql:8.0
                                    
                                    echo "⏳ Attente du démarrage de MySQL (30s)..."
                                    sleep 30
                                    echo "✅ MySQL Staging installé"
                                fi
                                
                                # 2. Pull image Docker
                                echo "🐳 Pull de l image Docker..."
                                docker pull ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
                                
                                # 3. Arrêt ancien container
                                echo "🛑 Arrêt de l ancien container staging..."
                                docker stop paymybuddy-staging 2>/dev/null || true
                                docker rm paymybuddy-staging 2>/dev/null || true
                                
                                # 4. Démarrage nouveau container
                                echo "🚀 Lancement du nouveau container Staging..."
                                docker run -d --name paymybuddy-staging -p 8080:8080 \\
                                    -e SPRING_DATASOURCE_URL=jdbc:mysql://172.17.0.1:3306/db_paymybuddy \\
                                    -e SPRING_DATASOURCE_USERNAME=root \\
                                    -e SPRING_DATASOURCE_PASSWORD=password \\
                                    -e SPRING_PROFILES_ACTIVE=staging \\
                                    ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
                                
                                echo "✅ Déploiement Staging terminé !"
                                echo "🌐 URL: http://107.20.66.5:8080"
                            '
                        """
                    }
                }
                
                echo '✅ Application déployée en STAGING'
            }
        }

        // ====================================================================
        // STAGE 7 : TESTS DE VALIDATION STAGING (BRANCHE MAIN UNIQUEMENT)
        // ====================================================================
        stage('Tests de Validation Staging') {
            when {
                expression {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    branchName = branchName.replaceAll('origin/', '')
                    return branchName == 'main'
                }
            }
            steps {
                echo '🏥 Vérification de la santé de l application Staging...'
                
                script {
                    echo 'Attente du démarrage de l application (30s)...'
                    sleep 30
                    
                    def healthCheckResult = sh(
                        script: "curl -f http://107.20.66.5:8080/actuator/health",
                        returnStatus: true
                    )
                    
                    if (healthCheckResult == 0) {
                        echo '✅ Application Staging en bonne santé'
                    } else {
                        error '❌ Le health check Staging a échoué'
                    }
                }
            }
        }

        // ====================================================================
        // STAGE 8 : DÉPLOIEMENT PRODUCTION (BRANCHE MAIN UNIQUEMENT)
        // ====================================================================
        stage('Déploiement Production') {
            when {
                expression {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    branchName = branchName.replaceAll('origin/', '')
                    return branchName == 'main'
                }
            }
            steps {
                echo '🚀 Déploiement en environnement de PRODUCTION...'
                
                // Validation manuelle
                input message: '⚠️  Déployer en PRODUCTION ?', ok: 'Déployer'
                
                sshagent(['aws-ssh-prod']) {
                    script {
                        def buildNumber = env.BUILD_NUMBER
                        def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: 'main'
                        branchName = branchName.replaceAll('origin/', '')
                        def branchTag = branchName.replaceAll('/', '-')
                        
                        sh """
                            ssh -o StrictHostKeyChecking=no ${EC2_PROD_USER}@${EC2_PROD_IP} '
                                echo "=========================================="
                                echo "  DÉPLOIEMENT PRODUCTION - Build #${buildNumber}"
                                echo "=========================================="
                                
                                # 1. Vérification MySQL
                                echo "📦 Vérification de MySQL Production..."
                                if docker ps | grep -q mysql-prod; then
                                    echo "✅ MySQL Production déjà en cours d execution"
                                else
                                    echo "📥 Installation de MySQL Production..."
                                    docker rm mysql-prod 2>/dev/null || true
                                    
                                    docker run -d \\
                                        --name mysql-prod \\
                                        -p 3306:3306 \\
                                        -e MYSQL_ROOT_PASSWORD=password \\
                                        -e MYSQL_DATABASE=db_paymybuddy \\
                                        --restart unless-stopped \\
                                        mysql:8.0
                                    
                                    echo "⏳ Attente du démarrage de MySQL (30s)..."
                                    sleep 30
                                    echo "✅ MySQL Production installé"
                                fi
                                
                                # 2. Pull image Docker
                                echo "🐳 Pull de l image Docker Production..."
                                docker pull ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
                                
                                # 3. Arrêt ancien container
                                echo "🛑 Arrêt de l ancien container production..."
                                docker stop paymybuddy-prod 2>/dev/null || true
                                docker rm paymybuddy-prod 2>/dev/null || true
                                
                                # 4. Démarrage nouveau container
                                echo "🚀 Lancement du nouveau container Production..."
                                docker run -d --name paymybuddy-prod -p 8080:8080 \\
                                    -e SPRING_DATASOURCE_URL=jdbc:mysql://172.17.0.1:3306/db_paymybuddy \\
                                    -e SPRING_DATASOURCE_USERNAME=root \\
                                    -e SPRING_DATASOURCE_PASSWORD=password \\
                                    -e SPRING_PROFILES_ACTIVE=production \\
                                    ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
                                
                                echo "✅ Déploiement Production terminé !"
                                echo "🌐 URL: http://54.234.61.221:8080"
                            '
                        """
                    }
                }
                
                echo '✅ Application déployée en PRODUCTION'
            }
        }
        
        // ====================================================================
        // STAGE 9 : TESTS DE VALIDATION PRODUCTION (BRANCHE MAIN UNIQUEMENT)
        // ====================================================================
        stage('Tests de Validation Production') {
            when {
                expression {
                    def branchName = env.BRANCH_NAME ?: env.GIT_BRANCH ?: ''
                    branchName = branchName.replaceAll('origin/', '')
                    return branchName == 'main'
                }
            }
            steps {
                echo '🏥 Vérification de la santé de l application Production...'
                
                script {
                    echo 'Attente du démarrage de l application (30s)...'
                    sleep 30
                    
                    def healthCheckResult = sh(
                        script: "curl -f http://54.234.61.221:8080/actuator/health",
                        returnStatus: true
                    )
                    
                    if (healthCheckResult == 0) {
                        echo '✅ Application Production en bonne santé'
                    } else {
                        error '❌ Le health check Production a échoué'
                    }
                }
            }
        }
	}

    // ========================================================================
    // POST : Actions après la pipeline
    // ========================================================================
    post {
        success {
            script {
                def duration = currentBuild.durationString.replace(' and counting', '')
                def message = ""
                
                if (env.BRANCH_NAME == 'main') {
                    message = """
:white_check_mark: *Pipeline SUCCESS - MAIN*
Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Branch: ${env.BRANCH_NAME}
Duration: ${duration}

:rocket: *Déployé en:*
- Staging: http://107.20.66.5:8080
- Production: http://54.234.61.221:8080
                    """
                } else {
                    message = """
:white_check_mark: *Pipeline SUCCESS*
Job: ${env.JOB_NAME}
Build: #${env.BUILD_NUMBER}
Branch: ${env.BRANCH_NAME}
Duration: ${duration}

:package: Tests, SonarCloud et Build réussis
                    """
                }
                
                sh """
                    curl -X POST ${SLACK_WEBHOOK} \
                        -H 'Content-Type: application/json' \
                        -d '{
                            "attachments": [{
                                "color": "good",
                                "text": "${message}",
                                "footer": "Jenkins CI/CD Pipeline",
                                "ts": ${System.currentTimeMillis() / 1000}
                            }]
                        }'
                """
            }
            
            echo '✅ Pipeline exécutée avec succès!'
        }
        
        failure {
            script {
                def duration = currentBuild.durationString.replace(' and counting', '')
                
                sh """
                    curl -X POST ${SLACK_WEBHOOK} \
                        -H 'Content-Type: application/json' \
                        -d '{
                            "attachments": [{
                                "color": "danger",
                                "text": ":x: *Pipeline FAILURE*\\nJob: ${env.JOB_NAME}\\nBuild: #${env.BUILD_NUMBER}\\nBranch: ${env.BRANCH_NAME}\\nDuration: ${duration}",
                                "footer": "Jenkins CI/CD Pipeline",
                                "ts": ${System.currentTimeMillis() / 1000}
                            }]
                        }'
                """
            }
            
            echo '❌ Pipeline échouée!'
        }
        
        always {
            cleanWs()
            echo '🧹 Workspace nettoyé'
        }
    }
}
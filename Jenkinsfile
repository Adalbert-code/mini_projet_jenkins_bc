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
    // Agent none = on définit l'agent spécifiquement pour chaque stage
    // Cela permet d'utiliser différents agents Docker selon les besoins
    agent none
    
    // Variables d'environnement globales accessibles dans tous les stages
    environment {
        // ====================================================================
        // DOCKER CONFIGURATION
        // ====================================================================
        
        // Récupère les credentials DockerHub depuis Jenkins (username + password)
        // ID du credential: 'dockerhub-credentials'
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        
        // Nom de l'image Docker (format: username/nom-app)
        DOCKER_IMAGE = "adal2022/paymybuddy"
        
        // Tag de l'image = numéro du build Jenkins (ex: build #15 → tag "15")
        // Permet de tracer quelle version de l'app correspond à quel build
        DOCKER_TAG = "${env.BUILD_NUMBER}"
        
        // ====================================================================
        // SONARCLOUD CONFIGURATION
        // ====================================================================
        
        // Token d'authentification SonarCloud (récupéré depuis Jenkins credentials)
        SONAR_TOKEN = credentials('sonarcloud-token')
        
        // Clé unique du projet sur SonarCloud
        SONAR_PROJECT_KEY = "Adalbert-code_paymybuddy00"
        
        // Organisation SonarCloud (ton compte)
        SONAR_ORG = "adalbert-code"
        
        // ====================================================================
        // AWS EC2 CONFIGURATION
        // ====================================================================
        
        // IP publique du serveur de staging (pré-production)
        STAGING_HOST = "3.208.15.55"
        
        // IP publique du serveur de production
        PROD_HOST = "34.227.52.210"
        
        // Username SSH pour se connecter aux instances Ubuntu
        SSH_USER = "ubuntu"
        
        // ====================================================================
        // SLACK NOTIFICATION CONFIGURATION
        // ====================================================================
        
        // URL du webhook Slack pour envoyer les notifications
        SLACK_WEBHOOK = credentials('slack-webhook')
    }
    
    // ========================================================================
    // STAGES - Étapes séquentielles de la pipeline
    // ========================================================================
    stages {
        
        // ====================================================================
        // STAGE 1: CHECKOUT
        // ====================================================================
        // Clone le code source depuis GitLab
        // Exécuté sur: N'importe quel agent Jenkins disponible
        // ====================================================================
        stage('Checkout') {
            agent any
            
            steps {
                // Clone la branche 'main' du repo GitLab
                // Pas besoin de credentials car le repo est public
                git branch: 'main', 
                    url: 'https://gitlab.com/Adalbert-code/paymybuddy00.git'
            }
        }
        
        // ====================================================================
        // STAGE 2: TESTS AUTOMATISÉS
        // ====================================================================
        // Exécute les tests unitaires et d'intégration avec Maven
        // Exécuté sur: Container Docker avec Maven + Java 11
        // Condition: Toutes les branches (main et autres)
        // ====================================================================
        stage('Tests Automatisés') {
            agent {
                docker {
                    // Image Docker officielle Maven avec Java 17
                    image 'maven:3.9-amazoncorretto-17'
                    
                    // Monte le cache Maven local pour accélérer les builds
                    // Sans ça, Maven retélécharge toutes les dépendances à chaque build
                    args '-v /root/.m2:/root/.m2'
                }
            }
            
            // Condition d'exécution: Ce stage s'exécute sur TOUTES les branches
            // anyOf + not { branch 'main' } = toutes les branches possibles
            when {
                anyOf {
                    branch 'main'           // Branche principale
                    not { branch 'main' }   // Toutes les autres branches
                }
            }
            
            steps {
                // Exécute les tests Maven
                // clean = nettoie les anciens builds
                // test = lance tous les tests unitaires et d'intégration
                sh 'mvn clean test'
            }
            
            // Actions post-exécution (même si le stage échoue)
            post {
                always {
                    // Publie les résultats des tests au format JUnit
                    // Jenkins affichera un graphique des tests dans l'interface
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }
        
        // ====================================================================
        // STAGE 3: VÉRIFICATION QUALITÉ DU CODE - SONARCLOUD
        // ====================================================================
        // Analyse statique du code pour détecter:
        // - Bugs potentiels
        // - Vulnérabilités de sécurité
        // - Code smells (mauvaises pratiques)
        // - Duplication de code
        // - Couverture de tests
        // Exécuté sur: Container Docker Maven
        // Condition: Toutes les branches
        // ====================================================================
        stage('Vérification Qualité du Code - SonarCloud') {
            agent {
                docker {
                    image 'maven:3.9-amazoncorretto-17'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            
            // S'exécute sur toutes les branches
            when {
                anyOf {
                    branch 'main'
                    not { branch 'main' }
                }
            }
            
            steps {
                // withSonarQubeEnv configure automatiquement les variables d'env SonarQube
                // 'SonarCloud' = nom du serveur SonarQube configuré dans Jenkins
                // IMPORTANT: Ce serveur doit être configuré dans Jenkins > Configure System
                // withSonarQubeEnv('SonarCloud') {
                    sh """
                        mvn sonar:sonar \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.organization=${SONAR_ORG} \
                        -Dsonar.host.url=https://sonarcloud.io \
                        -Dsonar.login=${SONAR_TOKEN}
                    """
                //}
            }
        }
        
        // ====================================================================
        // STAGE 4: COMPILATION ET PACKAGING
        // ====================================================================
        // Compile le code Java et génère le fichier JAR exécutable
        // Ce JAR sera ensuite copié dans l'image Docker
        // Exécuté sur: Container Docker Maven
        // Condition: Toutes les branches
        // ====================================================================
        stage('Compilation et Packaging') {
            agent {
                docker {
                    image 'maven:3.9-amazoncorretto-17'
                    args '-v /root/.m2:/root/.m2'
                }
            }
            
            // S'exécute sur toutes les branches
            when {
                anyOf {
                    branch 'main'
                    not { branch 'main' }
                }
            }
            
            steps {
                // package = compile + crée le JAR
                // -DskipTests = skip les tests (déjà exécutés au stage 2)
                // Produit: target/paymybuddy-X.X.X.jar
                sh 'mvn clean package -DskipTests'
            }
            
            // Actions post-build
            post {
                success {
                    // Archive le JAR généré pour le garder dans Jenkins
                    // Utile pour télécharger manuellement si besoin
                    // fingerprint = Jenkins calcule un hash pour tracer le fichier
                    archiveArtifacts artifacts: '**/target/*.jar', fingerprint: true
                }
            }
        }
        
        // ====================================================================
        // STAGE 5: BUILD ET PUSH DOCKER IMAGE
        // ====================================================================
        // 1. Construit l'image Docker à partir du Dockerfile
        // 2. Tag l'image avec le numéro de build et 'latest'
        // 3. Push l'image vers DockerHub
        // Exécuté sur: Agent Jenkins (avec Docker installé)
        // Condition: Toutes les branches
        // ====================================================================
        stage('Build et Push Docker Image') {
            agent any  // Agent avec Docker Engine installé
            
            // S'exécute sur toutes les branches
            when {
                anyOf {
                    branch 'main'
                    not { branch 'main' }
                }
            }
            
            steps {
                script {
                    // BUILD DE L'IMAGE DOCKER
                    // -t = tag l'image
                    // . = contexte de build = répertoire courant (contient le Dockerfile)
                    // Première image: adal2022/paymybuddy:15 (si build #15)
                    // Deuxième image: adal2022/paymybuddy:latest
                    sh """
                        docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} .
                        docker tag ${DOCKER_IMAGE}:${DOCKER_TAG} ${DOCKER_IMAGE}:latest
                    """
                    
                    // PUSH VERS DOCKERHUB
                    // 1. Login avec les credentials Jenkins
                    //    $DOCKERHUB_CREDENTIALS_USR = username
                    //    $DOCKERHUB_CREDENTIALS_PSW = password
                    //    --password-stdin = lit le password depuis stdin (plus sécurisé)
                    // 2. Push les deux tags (numéro de build + latest)
                    // 3. Logout pour sécurité
                    sh """
                        echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
                        docker push ${DOCKER_IMAGE}:${DOCKER_TAG}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    """
                }
            }
        }
        
        // ====================================================================
        // STAGE 6: DÉPLOIEMENT STAGING
        // ====================================================================
        // Déploie l'application sur le serveur de staging (pré-production)
        // 1. Installe/Vérifie MySQL avec Docker
        // 2. Pull l'image Docker de l'application depuis DockerHub
        // 3. Arrête et supprime l'ancien container applicatif
        // 4. Lance le nouveau container applicatif
        // Exécuté sur: Agent Jenkins
        // Connexion: SSH vers instance EC2 staging
        // Condition: UNIQUEMENT sur la branche 'main'
        // ====================================================================
        stage('Déploiement Staging') {
            agent any
            
            // IMPORTANT: Ce stage s'exécute UNIQUEMENT sur la branche main
            // Les autres branches (develop, feature/*) ne déploient PAS
            // when {
            //    branch 'main'
            //}
            
            steps {
                // sshagent = utilise les credentials SSH pour se connecter
                // 'aws-ssh-staging' = ID du credential dans Jenkins (clé privée .pem)
                sshagent(credentials: ['aws-ssh-staging']) {
                    sh """
                        # Se connecter en SSH à l'instance staging
                        # -o StrictHostKeyChecking=no = ne demande pas de confirmer le fingerprint
                        # Les commandes entre quotes sont exécutées sur le serveur distant
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${STAGING_HOST} '
                            # ============================================================
                            # ÉTAPE 1: INSTALLATION/VÉRIFICATION MYSQL
                            # ============================================================
                            echo "🔍 Vérification de MySQL..."
                            
                            # Vérifie si MySQL tourne déjà
                            if docker ps | grep -q mysql-staging; then
                                echo "✅ MySQL est déjà en cours d'\''exécution"
                            else
                                echo "📦 Installation de MySQL..."
                                
                                # Supprime l'ancien container MySQL s'\''il existe (mais arrêté)
                                docker rm mysql-staging 2>/dev/null || true
                                
                                # Lance MySQL avec Docker
                                # -d = mode détaché
                                # --name = nom du container
                                # -p 3306:3306 = expose le port MySQL
                                # -e = variables d'\''environnement pour la config MySQL
                                # --restart unless-stopped = redémarre automatiquement sauf si arrêté manuellement
                                docker run -d \
                                    --name mysql-staging \
                                    -p 3306:3306 \
                                    -e MYSQL_ROOT_PASSWORD=password \
                                    -e MYSQL_DATABASE=db_paymybuddy \
                                    --restart unless-stopped \
                                    mysql:8.0
                                
                                echo "⏳ Attente du démarrage de MySQL (30 secondes)..."
                                sleep 30
                                
                                echo "✅ MySQL installé et démarré"
                            fi
                            
                            # ============================================================
                            # ÉTAPE 2: DÉPLOIEMENT DE L'\''APPLICATION
                            # ============================================================
                            echo "📥 Pull de l'\''image Docker de l'\''application..."
                            docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "🛑 Arrêt de l'\''ancien container applicatif..."
                            # Arrête le container existant (|| true = ne pas échouer si inexistant)
                            docker stop paymybuddy-staging || true
                            
                            echo "🗑️  Suppression de l'\''ancien container..."
                            # Supprime le container existant
                            docker rm paymybuddy-staging || true
                            
                            echo "🚀 Lancement du nouveau container..."
                            # Lance le nouveau container
                            # -d = mode détaché (en arrière-plan)
                            # --name = nom du container
                            # -p 8080:8080 = map le port 8080 du container vers le port 8080 de l'\''hôte
                            # Les variables d'\''environnement Spring sont déjà dans l'\''image Docker
                            docker run -d --name paymybuddy-staging -p 8080:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "✅ Déploiement staging terminé!"
                        '
                    """
                }
            }
        }
        
        // ====================================================================
        // STAGE 7: TESTS DE VALIDATION STAGING
        // ====================================================================
        // Vérifie que l'application déployée fonctionne correctement
        // Utilise le endpoint /actuator/health de Spring Boot
        // Exécuté sur: Agent Jenkins
        // Condition: UNIQUEMENT sur la branche 'main'
        // ====================================================================
        stage('Tests de Validation Staging') {
            agent any
            
            // S'exécute uniquement sur main (après déploiement staging)
            //when {
            //    branch 'main'
            //}
            
            steps {
                script {
                    // Attend 30 secondes pour laisser l'application démarrer
                    // Spring Boot peut prendre du temps à initialiser
                    sleep(time: 30, unit: 'SECONDS')
                    
                    // Health check via curl
                    // -f = échoue si le serveur retourne une erreur HTTP (404, 500, etc.)
                    // Si l'app ne répond pas ou retourne une erreur, le build échoue
                    sh """
                        curl -f http://${STAGING_HOST}:8080/actuator/health || exit 1
                    """
                }
            }
        }
        
        // ====================================================================
        // STAGE 8: DÉPLOIEMENT PRODUCTION
        // ====================================================================
        // Déploie l'application sur le serveur de production
        // IMPORTANT: Nécessite une validation manuelle avant de procéder!
        // 1. Installe/Vérifie MySQL avec Docker
        // 2. Pull l'image Docker de l'application depuis DockerHub
        // 3. Arrête et supprime l'ancien container applicatif
        // 4. Lance le nouveau container applicatif
        // Exécuté sur: Agent Jenkins
        // Connexion: SSH vers instance EC2 production
        // Condition: UNIQUEMENT sur la branche 'main'
        // ====================================================================
        stage('Déploiement Production') {
            agent any
            
            // S'exécute uniquement sur main
            //when {
            //    branch 'main'
            //}
            
            steps {
                // VALIDATION MANUELLE REQUISE
                // La pipeline se met en pause et attend qu'un humain clique sur "Déployer"
                // Sécurité: évite les déploiements accidentels en production
                input message: 'Déployer en production?', ok: 'Déployer'
                
                // Connexion SSH avec les credentials production
                sshagent(credentials: ['aws-ssh-prod']) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${SSH_USER}@${PROD_HOST} '
                            # ============================================================
                            # ÉTAPE 1: INSTALLATION/VÉRIFICATION MYSQL
                            # ============================================================
                            echo "🔍 Vérification de MySQL..."
                            
                            # Vérifie si MySQL tourne déjà
                            if docker ps | grep -q mysql-prod; then
                                echo "✅ MySQL est déjà en cours d'\''exécution"
                            else
                                echo "📦 Installation de MySQL..."
                                
                                # Supprime l'ancien container MySQL s'\''il existe (mais arrêté)
                                docker rm mysql-prod 2>/dev/null || true
                                
                                # Lance MySQL avec Docker
                                # IMPORTANT: En production, utilise des secrets plus sécurisés!
                                docker run -d \
                                    --name mysql-prod \
                                    -p 3306:3306 \
                                    -e MYSQL_ROOT_PASSWORD=password \
                                    -e MYSQL_DATABASE=db_paymybuddy \
                                    --restart unless-stopped \
                                    mysql:8.0
                                
                                echo "⏳ Attente du démarrage de MySQL (30 secondes)..."
                                sleep 30
                                
                                echo "✅ MySQL installé et démarré"
                            fi
                            
                            # ============================================================
                            # ÉTAPE 2: DÉPLOIEMENT DE L'\''APPLICATION
                            # ============================================================
                            echo "📥 Pull de l'\''image Docker de l'\''application..."
                            docker pull ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "🛑 Arrêt de l'\''ancien container applicatif..."
                            docker stop paymybuddy-prod || true
                            
                            echo "🗑️  Suppression de l'\''ancien container..."
                            docker rm paymybuddy-prod || true
                            
                            echo "🚀 Lancement du nouveau container..."
                            docker run -d --name paymybuddy-prod -p 8080:8080 ${DOCKER_IMAGE}:${DOCKER_TAG}
                            
                            echo "✅ Déploiement production terminé!"
                        '
                    """
                }
            }
        }
        
        // ====================================================================
        // STAGE 9: TESTS DE VALIDATION PRODUCTION
        // ====================================================================
        // Vérifie que l'application en production fonctionne
        // Identique aux tests staging mais sur le serveur de production
        // Exécuté sur: Agent Jenkins
        // Condition: UNIQUEMENT sur la branche 'main'
        // ====================================================================
        stage('Tests de Validation Production') {
            agent any
            
            // when {
            //    branch 'main'
            //}
            
            steps {
                script {
                    // Attend que l'app démarre
                    sleep(time: 30, unit: 'SECONDS')
                    
                    // Health check production
                    sh """
                        curl -f http://${PROD_HOST}:8080/actuator/health || exit 1
                    """
                }
            }
        }
    }
    
    // ========================================================================
    // POST - Actions exécutées après TOUS les stages
    // ========================================================================
    // Ces actions s'exécutent quelle que soit l'issue de la pipeline
    // (succès, échec, ou annulation)
    // ========================================================================
    post {
        // ====================================================================
        // ALWAYS: S'exécute TOUJOURS (succès ou échec)
        // ====================================================================
        // Envoie une notification Slack avec le statut de la pipeline
        // ====================================================================
        always {
            script {
                // Détermine le statut du build
                // currentBuild.result peut être: SUCCESS, FAILURE, UNSTABLE, ABORTED
                // Si null (pas encore défini), on considère SUCCESS
                def status = currentBuild.result ?: 'SUCCESS'
                
                // Couleur du message Slack
                // 'good' (vert) si SUCCESS, 'danger' (rouge) sinon
                def color = status == 'SUCCESS' ? 'good' : 'danger'
                
                // Emoji selon le statut
                def emoji = status == 'SUCCESS' ? ':white_check_mark:' : ':x:'
                
                // Message formaté pour Slack (échappement pour éviter les erreurs JSON)
                def message = "${emoji} Pipeline ${status} - Job: ${env.JOB_NAME} Build: #${env.BUILD_NUMBER}"
                
                // Utilise catchError pour ne pas faire échouer le build si Slack échoue
                catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    // Utilise httpRequest ou sh selon disponibilité
                    // On wrap dans un try-catch pour gérer l'absence d'agent
                    try {
                        sh """
                            curl -X POST '${SLACK_WEBHOOK}' \
                            -H 'Content-Type: application/json' \
                            -d '{"text": "${message}"}'
                        """
                    } catch (Exception e) {
                        echo "Failed to send Slack notification: ${e.message}"
                    }
                }
            }
        }
        
        // ====================================================================
        // SUCCESS: S'exécute uniquement si la pipeline réussit
        // ====================================================================
        success {
            echo '✅ Pipeline exécutée avec succès!'
            echo '📦 Application déployée et validée'
        }
        
        // ====================================================================
        // FAILURE: S'exécute uniquement si la pipeline échoue
        // ====================================================================
        failure {
            echo '❌ Pipeline échouée!'
            echo '🔍 Vérifiez les logs pour identifier le problème'
            // Ici on pourrait ajouter d'autres actions:
            // - Envoyer un email aux développeurs
            // - Créer un ticket Jira automatiquement
            // - Rollback automatique
        }
    }
}

/*
 * ============================================================================
 * NOTES IMPORTANTES
 * ============================================================================
 * 
 * 1. GITFLOW:
 *    - Branche 'main': Exécute TOUS les stages (tests → déploiement prod)
 *    - Autres branches: Exécute seulement tests, qualité, build, push Docker
 * 
 * 2. CREDENTIALS REQUIS DANS JENKINS:
 *    - dockerhub-credentials (Username with password)
 *    - sonarcloud-token (Secret text)
 *    - slack-webhook (Secret text)
 *    - aws-ssh-staging (SSH Username with private key)
 *    - aws-ssh-prod (SSH Username with private key)
 * 
 * 3. PRÉREQUIS SERVEURS AWS:
 *    - Docker installé sur les deux instances EC2
 *    - Security Groups: ports 22 (SSH) et 8080 (HTTP) ouverts
 *    - User 'ubuntu' doit pouvoir exécuter Docker sans sudo
 * 
 * 4. PRÉREQUIS APPLICATION:
 *    - Spring Boot Actuator configuré (endpoint /actuator/health)
 *    - Application écoute sur le port 8080
 *    - Dockerfile présent à la racine du projet
 * 
 * 5. CONFIGURATION JENKINS:
 *    - SonarCloud server configuré dans Jenkins > Configure System
 *    - Nom du serveur doit être exactement: 'SonarCloud'
 * 
 * ============================================================================
 */

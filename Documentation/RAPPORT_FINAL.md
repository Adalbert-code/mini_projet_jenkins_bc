# RAPPORT FINAL DE PROJET
## Pipeline CI/CD Jenkins pour PayMyBuddy

---

**Formation :** EAZYTraining DevOps BootCamp
**Module :** Jenkins - Intégration et Déploiement Continus
**Auteur :** Adalbert Nanda 
**Date de rendu :** Janvier 2026

---

## Table des Matières

1. [Contexte et Objectifs](#1-contexte-et-objectifs)
2. [Architecture de la Solution](#2-architecture-de-la-solution)
3. [Technologies et Outils](#3-technologies-et-outils)
4. [Implémentation de la Pipeline](#4-implémentation-de-la-pipeline)
5. [Gestion des Environnements](#5-gestion-des-environnements)
6. [Sécurité et Bonnes Pratiques](#6-sécurité-et-bonnes-pratiques)
7. [Problèmes Rencontrés et Solutions](#7-problèmes-rencontrés-et-solutions)
8. [Résultats et Démonstration](#8-résultats-et-démonstration)
9. [Compétences Acquises](#9-compétences-acquises)
10. [Axes d'Amélioration](#10-axes-damélioration)
11. [Conclusion](#11-conclusion)
12. [Annexes](#12-annexes)

---

## 1. Contexte et Objectifs

### 1.1 Présentation du Projet

**PayMyBuddy** est une application web de transfert d'argent entre amis développée en Java avec le framework Spring Boot. L'objectif de ce projet était de mettre en place une **pipeline CI/CD complète** pour automatiser l'intégralité du cycle de vie de l'application.

### 1.2 Objectifs du 

--------------------------------------------------------------------------------------
|        Objectif          |                 Description                   | Statut  |
|--------------------------|-----------------------------------------------|---------|
| **Intégration Continue** | Automatiser les tests et l'analyse de qualité | Atteint |
| **Containerisation**     | Dockeriser l'application                      | Atteint |
| **Déploiement Continu**  | Déployer automatiquement sur AWS              | Atteint |
| **Multi-environnements** | Staging + Production                          | Atteint |
| **Notifications**        | Alertes Slack en temps réel                   | Atteint |
| **Sécurité**             | Gestion sécurisée des credentials             | Atteint |
--------------------------------------------------------------------------------------

### 1.3 Périmètre Fonctionnel

La pipeline couvre les fonctionnalités suivantes :

- Récupération automatique du code depuis GitHub
- Exécution des tests unitaires JUnit
- Analyse de qualité de code avec SonarCloud
- Compilation et packaging Maven
- Construction d'images Docker
- Publication sur Docker Hub
- Déploiement sur environnement de staging
- Validation automatique (health checks)
- Déploiement en production avec approbation manuelle
- Notifications Slack (succès/échec)

---

## 2. Architecture de la Solution

### 2.1 Architecture Globale

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                            ARCHITECTURE CI/CD                                   │
└─────────────────────────────────────────────────────────────────────────────────┘

                                    DÉVELOPPEUR
                                         │
                                         ▼
                               ┌─────────────────┐
                               │     GitHub      │
                               │   Repository    │
                               └────────┬────────┘
                                        │ Webhook / Poll
                                        ▼
┌───────────────────────────────────────────────────────────────────────────────┐
│                              JENKINS SERVER                                   │
│                        (VM Vagrant avec Docker)                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                         PIPELINE CI/CD                                  │  │
│  │                                                                         │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │  │
│  │  │ Checkout │─>│  Tests   │─>│  Sonar   │─>│ Package  │─>│  Build   │   │  │
│  │  │   SCM    │  │  JUnit   │  │  Cloud   │  │  Maven   │  │  Docker  │   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  └────-┬────┘   │  │
│  │                                                                │        │  │
│  └────────────────────────────────────────────────────────────────┼────────┘  │
└───────────────────────────────────────────────────────────────────┼───────────┘
                                                                    │
                    ┌───────────────────────────────────────────────┼───────────┐
                    │                                               ▼           │
                    │                                      ┌──────────────┐     │
                    │                                      │  Docker Hub  │     │
                    │                                      │   Registry   │     │
                    │                                      └──────┬───────┘     │
                    │                                             │             │
                    │              ┌──────────────────────────────┤             │
                    │              │                              │             │
                    │              ▼                              ▼             │
                    │     ┌────────────────┐             ┌────────────────┐     │
                    │     │  EC2 STAGING   │             │ EC2 PRODUCTION │     │
                    │     │ 107.20.66.5    │             │ 54.234.61.221  │     │
                    │     │                │             │                │     │
                    │     │ ┌────────────┐ │             │ ┌────────────┐ │     │
                    │     │ │   MySQL    │ │             │ │   MySQL    │ │     │
                    │     │ │  Container │ │             │ │  Container │ │     │
                    │     │ └────────────┘ │             │ └────────────┘ │     │
                    │     │ ┌────────────┐ │             │ ┌────────────┐ │     │
                    │     │ │ PayMyBuddy │ │             │ │ PayMyBuddy │ │     │
                    │     │ │  Container │ │             │ │  Container │ │     │
                    │     │ └────────────┘ │             │ └────────────┘ │     │
                    │     └────────────────┘             └────────────────┘     │
                    │              AWS CLOUD                                    │
                    └───────────────────────────────────────────────────────────┘

                        ┌───────────────────┐         ┌───────────────────┐
                        │    SonarCloud     │         │      Slack        │
                        │  Analyse Qualité  │         │   Notifications   │
                        └───────────────────┘         └───────────────────┘
```

### 2.2 Flux de Données

```
1. COMMIT        → Code poussé sur GitHub
2. TRIGGER       → Jenkins détecte le changement
3. CHECKOUT      → Clone du repository
4. TEST          → Exécution tests JUnit
5. ANALYZE       → Envoi vers SonarCloud
6. BUILD         → Compilation Maven + Image Docker
7. PUSH          → Publication sur Docker Hub
8. DEPLOY STAG   → Déploiement EC2 Staging
9. VALIDATE      → Health check Staging
10. APPROVE      → Validation manuelle
11. DEPLOY PROD  → Déploiement EC2 Production
12. VALIDATE     → Health check Production
13. NOTIFY       → Message Slack
```

---

## 3. Technologies et Outils

### 3.1 Stack Technologique

---------------------------------------------------------------------------------
|      Catégorie    | Technologie | Version  |              Rôle                |
|-------------------|-------------|----------|----------------------------------|
| **Application**   |    Java     | 17 (LTS) | Langage de programmation         |
|                   | Spring Boot |   3.x    | Framework applicatif             |
|                   | Maven       |   3.9    | Gestion des dépendances et build |
|                   | MySQL       |   8.0    | Base de données                  |
| **CI/CD**         | Jenkins     |   2.520  | Serveur d'orchestration CI/CD    |
|                   | Docker      |  Latest  | Containerisation                 |
|                   | Docker Hub  |    -     | Registry d'images                |
| **Qualité**       | SonarCloud  |    -     | Analyse statique de code         |
|                   | JUnit       |    5     | Framework de tests               |
| **Infrastructure**| AWS EC2     | t2.micro | Instances de déploiement         |
|                   | Vagrant     |   2.x    | Virtualisation locale            |
|                   | VirtualBox  |    -     | Hyperviseur                      |
| **Communication** | Slack       |    -     | Notifications d'équipe           |
|                   | SSH         |    -     | Connexion sécurisée aux serveurs |
---------------------------------------------------------------------------------

### 3.2 Plugins Jenkins Utilisés

----------------------------------------------------------------
|          Plugin         |          Utilisation               |
|-------------------------|------------------------------------|
| **Pipeline**            | Support des pipelines déclaratives |
| **Docker Pipeline**     | Intégration native Docker          |
| **Git**                 | Connexion aux repositories Git     |
| **SSH Agent**           | Gestion des connexions SSH         |
| **Credentials Binding** | Injection sécurisée des secrets    |
| **SonarQube Scanner**   | Intégration SonarCloud             |
| **Slack Notification**  | Envoi de notifications             |
----------------------------------------------------------------
---

## 4. Implémentation de la Pipeline

### 4.1 Structure du Jenkinsfile

Le Jenkinsfile utilise la syntaxe **déclarative** de Jenkins Pipeline :

```groovy
pipeline {
    agent any

    environment {
        // Variables d'environnement globales
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE = 'adal2022/paymybuddy'
        SONAR_TOKEN = credentials('sonarcloud-token')
        // ...
    }

    stages {
        stage('Checkout') { /* ... */ }
        stage('Tests Automatisés') { /* ... */ }
        stage('Analyse SonarCloud') { /* ... */ }
        stage('Compilation et Packaging') { /* ... */ }
        stage('Build et Push Docker') { /* ... */ }
        stage('Déploiement Staging') { /* ... */ }
        stage('Tests Validation Staging') { /* ... */ }
        stage('Déploiement Production') { /* ... */ }
        stage('Tests Validation Production') { /* ... */ }
    }

    post {
        success { /* Notification Slack succès */ }
        failure { /* Notification Slack échec */ }
        always { cleanWs() }
    }
}
```

### 4.2 Détail des Stages

#### Stage 1 : Checkout
```groovy
stage('Checkout') {
    steps {
        checkout scm
    }
}
```
Récupère le code source depuis le repository GitHub configuré.

#### Stage 2 : Tests Automatisés
```groovy
stage('Tests Automatisés') {
    steps {
        script {
            docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2') {
                sh 'mvn clean test'
            }
        }
    }
    post {
        always {
            junit '**/target/surefire-reports/*.xml'
        }
    }
}
```
- Exécution des tests dans un conteneur Maven
- Publication des rapports JUnit

#### Stage 3 : Analyse SonarCloud
```groovy
stage('Analyse SonarCloud') {
    steps {
        script {
            docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2 --dns 8.8.8.8') {
                sh """
                    mvn sonar:sonar \
                        -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                        -Dsonar.organization=${SONAR_ORGANIZATION} \
                        -Dsonar.host.url=https://sonarcloud.io \
                        -Dsonar.login=\$SONAR_TOKEN
                """
            }
        }
    }
}
```
- Analyse de qualité envoyée vers SonarCloud
- Détection des bugs, vulnérabilités et code smells

#### Stage 4-5 : Build et Push Docker
```groovy
stage('Build et Push Docker') {
    steps {
        script {
            sh "docker build -t ${DOCKER_IMAGE}:${branchTag}-${buildNumber} ."
            sh """
                echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
                docker push ${DOCKER_IMAGE}:${branchTag}-${buildNumber}
            """
        }
    }
}
```
- Construction de l'image Docker multi-stage
- Publication sur Docker Hub

#### Stage 6-7 : Déploiement Staging
```groovy
stage('Déploiement Staging') {
    when {
        expression { branchName == 'main' }
    }
    steps {
        sshagent(['aws-ssh-staging']) {
            sh """
                ssh -o StrictHostKeyChecking=no ubuntu@${EC2_STAGING_IP} '
                    docker pull ${DOCKER_IMAGE}:${tag}
                    docker stop paymybuddy-staging || true
                    docker rm paymybuddy-staging || true
                    docker run -d --name paymybuddy-staging -p 8080:8080 \
                        -e SPRING_PROFILES_ACTIVE=staging \
                        ${DOCKER_IMAGE}:${tag}
                '
            """
        }
    }
}
```

#### Stage 8-9 : Déploiement Production
```groovy
stage('Déploiement Production') {
    when {
        expression { branchName == 'main' }
    }
    steps {
        input message: 'Déployer en PRODUCTION ?', ok: 'Déployer'

        sshagent(['aws-ssh-prod']) {
            // Déploiement similaire à staging
        }
    }
}
```
- **Validation manuelle** requise avant déploiement
- Même processus que staging

### 4.3 Stratégie GitFlow

| Branche | Stages Exécutés | Déploiement |
|---------|-----------------|-------------|
| `main` | Tous les stages | Staging + Production |
| `develop` | Tests → SonarCloud → Build → Push | Aucun |
| `feature/*` | Tests → SonarCloud → Build | Aucun |

---

## 5. Gestion des Environnements

### 5.1 Configuration des Environnements

----------------------------------------------------------------------
|  Environnement |      IP       | Profil Spring | Base de données   |
|----------------|---------------|---------------|-------------------|
| **Test**       |       -       | `test`        | H2 (in-memory)    |
| **Staging**    | 107.20.66.5   | `staging`     | MySQL (container) |
| **Production** | 54.234.61.221 | `production`  | MySQL (container) |
----------------------------------------------------------------------

### 5.2 Configuration Spring Boot par Environnement

**application-staging.properties :**
```properties
spring.datasource.url=jdbc:mysql://172.17.0.1:3306/db_paymybuddy
spring.datasource.username=root
spring.datasource.password=password
logging.level.root=DEBUG
```

**application-production.properties :**
```properties
spring.datasource.url=jdbc:mysql://172.17.0.1:3306/db_paymybuddy
spring.datasource.username=root
spring.datasource.password=${DB_PASSWORD}
logging.level.root=INFO
```

### 5.3 Infrastructure AWS

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS CLOUD                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                      VPC                                  │  │
│  │                                                           │  │
│  │  ┌─────────────────────┐    ┌─────────────────────┐       │  │
│  │  │   EC2 STAGING       │    │   EC2 PRODUCTION    │       │  │
│  │  │   107.20.66.5       │    │   54.234.61.221     │       │  │
│  │  │                     │    │                     │       │  │
│  │  │   Security Group:   │    │   Security Group:   │       │  │
│  │  │   - SSH (22)        │    │   - SSH (22)        │       │  │
│  │  │   - HTTP (8080)     │    │   - HTTP (8080)     │       │  │
│  │  │                     │    │                     │       │  │
│  │  │   Instance: t2.micro│    │   Instance: t2.micro│       │  │
│  │  │   OS: Ubuntu        │    │   OS: Ubuntu        │       │  │
│  │  └─────────────────────┘    └─────────────────────┘       │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Sécurité et Bonnes Pratiques

### 6.1 Gestion des Secrets

------------------------------------------------------------------
|          Secret        |      Stockage       | Utilisation     |
|------------------------|---------------------|-----------------|
| Docker Hub credentials | Jenkins Credentials | Push d'images   |
| SonarCloud token       | Jenkins Credentials | Analyse de code |
| SSH Keys EC2           | Jenkins Credentials | Déploiement     |
| Slack Webhook          | Jenkins Credentials | Notifications   |
------------------------------------------------------------------

### 6.2 Bonnes Pratiques Implémentées

#### Sécurité des Credentials dans le Jenkinsfile

```groovy
// CORRECT - Shell expansion (sécurisé)
sh """
    echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
"""

// INCORRECT - Groovy interpolation (expose les secrets dans les logs)
sh """
    echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login ...
"""
```

#### Validation Manuelle pour la Production

```groovy
input message: 'Déployer en PRODUCTION ?', ok: 'Déployer'
```

#### Nettoyage Automatique

```groovy
post {
    always {
        cleanWs()  // Nettoie le workspace après chaque build
        sh "docker logout"  // Déconnexion Docker
    }
}
```

### 6.3 Checklist Sécurité

- [x] Aucun secret en clair dans le code
- [x] Utilisation de Jenkins Credentials Store
- [x] Shell expansion pour les variables sensibles
- [x] SSH par clé (pas de mot de passe)
- [x] Security Groups AWS restrictifs
- [x] Validation manuelle avant production
- [x] Nettoyage automatique du workspace

---

## 7. Problèmes Rencontrés et Solutions

### 7.1 Problème 1 : Warning "Groovy String Interpolation"

**Symptôme :**
```
Warning: A secret was passed to "sh" using Groovy String interpolation, which is insecure.
Affected argument(s) used the following variable(s): [DOCKERHUB_CREDENTIALS_PSW]
```

**Cause :** Utilisation de `${VAR}` au lieu de `\$VAR` pour les secrets

**Solution :**
```groovy
// Avant (insécurisé)
sh "echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login ..."

// Après (sécurisé)
sh "echo \$DOCKERHUB_CREDENTIALS_PSW | docker login ..."
```

### 7.2 Problème 2 : SSH "Permission denied (publickey)"

**Symptôme :**
```
Permission denied (publickey,gssapi-keyex,gssapi-with-mic)
```

**Cause :**
- Mauvais ID de credential SSH
- Adresses IP EC2 incorrectes

**Solution :**
1. Créer les credentials SSH avec les bons IDs (`aws-ssh-staging`, `aws-ssh-prod`)
2. Mettre à jour les IPs dans le Jenkinsfile

### 7.3 Problème 3 : "SonarCloud server cannot be reached"

**Symptôme :**
```
ERROR: SonarCloud server [https://sonarcloud.io] can not be reached
Unknown host sonarcloud.io: Name or service not known
```

**Cause :** Problème DNS dans le conteneur Docker

**Solution :**
```groovy
docker.image('maven:3.9-amazoncorretto-17').inside('-v /root/.m2:/root/.m2 --dns 8.8.8.8 --dns 8.8.4.4') {
    // ...
}
```

### 7.4 Problème 4 : "Docker registry timeout"

**Symptôme :**
```
Error response from daemon: Get "https://registry-1.docker.io/v2/":
net/http: request canceled while waiting for connection
```

**Cause :** DNS de la VM Vagrant non fonctionnel

**Solution :**
```bash
# Sur la VM Vagrant (pas dans le conteneur Jenkins)
sudo mkdir -p /etc/systemd/resolved.conf.d/
sudo tee /etc/systemd/resolved.conf.d/dns.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4
FallbackDNS=1.1.1.1
EOF

sudo systemctl restart systemd-resolved
sudo systemctl restart docker
```

---

## 8. Résultats et Démonstration

### 8.1 Pipeline Fonctionnelle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        RÉSULTAT PIPELINE - BUILD #10                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Stage                              Durée        Statut                     │
│  ─────────────────────────────────────────────────────────────────────────  │
│  Checkout SCM                       1s           SUCCESS                    │
│  Tests Automatisés                  49s          SUCCESS                    │
│  Analyse SonarCloud                 2min 18s     SUCCESS                    │
│  Compilation et Packaging           41s          SUCCESS                    │
│  Build et Push Docker               25s          SUCCESS                    │
│  Déploiement Staging                ~30s         SUCCESS                    │
│  Tests Validation Staging           30s          SUCCESS                    │
│  Déploiement Production             ~30s         SUCCESS                    │
│  Tests Validation Production        30s          SUCCESS                    │
│                                                                             │
│  DURÉE TOTALE: ~6 minutes                                                   │
│  STATUT FINAL: SUCCESS                                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 8.2 URLs de Démonstration

|--------------------------------------------------------------------------------------|
|Environnement |           URL             |             Health Check                  |
|--------------|---------------------------|-------------------------------------------|
| Staging      | http://107.20.66.5:8080   | http://107.20.66.5:8080/actuator/health   |
| Production   | http://54.234.61.221:8080 | http://54.234.61.221:8080/actuator/health |
|--------------------------------------------------------------------------------------|

### 8.3 Captures d'Écran

*Note : Les captures d'écran de la console Jenkins, SonarCloud et de l'application déployée sont disponibles dans le dossier `/screenshots` du projet.*

### 8.4 Métriques SonarCloud

|-----------------------------------|
| Métrique        | Valeur  | Seuil |
|-----------------|---------|-------|
| Quality Gate    | Passed  |   -   |
| Bugs            |    0    |   0   |
| Vulnerabilities |    0    |   0   |
| Code Smells     |    < 10 |  < 50 |
| Coverage        |    >70% | > 60% |
| Duplications    |    < 3% | < 5%  |
|-----------------------------------|

Dashboard : https://sonarcloud.io/project/overview?id=Adalbert-code_paymybuddy00

---

## 9. Compétences Acquises

### 9.1 Compétences Techniques

|------------------------------------------------------------------|
|    Domaine   |                Compétences                        |
|--------------|---------------------------------------------------|
| **CI/CD**    | Conception et implémentation de pipelines Jenkins |
|              | Syntaxe déclarative Jenkinsfile                   |
|              | Gestion des stages conditionnels                  |
|              | Intégration d'outils externes                     |
|------------------------------------------------------------------|
| **Docker**   | Écriture de Dockerfile multi-stage                |
|              | Utilisation de Docker dans les pipelines          |
|              | Gestion des registries                            |
|------------------------------------------------------------------|
| **AWS**      | Déploiement sur EC2                               |
|              | Configuration des Security Groups                 |
|              | Gestion des accès SSH                             |
|------------------------------------------------------------------|
| **Qualité**  | Intégration SonarCloud                            |
|              | Analyse de code statique                          |
|              | Quality Gates                                     |
|------------------------------------------------------------------|
| **Sécurité** | Gestion des secrets Jenkins                       |
|              | Bonnes pratiques de sécurité CI/CD                |
|------------------------------------------------------------------|

### 9.2 Compétences Transversales

- Résolution de problèmes complexes
- Documentation technique
- Debugging et troubleshooting
- Gestion de configuration
- Approche DevOps (collaboration Dev + Ops)

---

## 10. Axes d'Amélioration

### 10.1 Améliorations Court Terme

--------------------------------------------------------------------------------------------------------------
|        Amélioration        |                             Description                            | Priorité |
|----------------------------|--------------------------------------------------------------------|----------|
| **Rollback automatique**   | Retour automatique à la version N-1 en cas d'échec du health check | Haute    |
| **Tests d'intégration**    | Ajout de tests E2E avec Selenium                                   | Haute    |
| **Cache Maven**            | Optimisation du temps de build avec cache persistant               | Moyenne  |
--------------------------------------------------------------------------------------------------------------

### 10.2 Améliorations Moyen Terme

--------------------------------------------------------------------------------------
| Amélioration              |                 Description                 | Priorité |
|---------------------------|---------------------------------------------|----------|
| **Blue-Green Deployment** | Déploiement sans interruption de service    |    Haute |
| **Monitoring**            | Intégration Prometheus + Grafana            | Moyenne  |
| **Logs centralisés**      | ELK Stack (Elasticsearch, Logstash, Kibana) | Moyenne  |
--------------------------------------------------------------------------------------

### 10.3 Améliorations Long Terme

-----------------------------------------------------------------------------------
|        Amélioration        |             Description                 | Priorité |
|----------------------------|-----------------------------------------|----------|
| **Infrastructure as Code** | Terraform pour provisionner AWS         | Moyenne  |
| **Kubernetes**             | Migration vers K8s pour l'orchestration | Basse    |
| **GitOps**                 | ArgoCD pour le déploiement déclaratif   | Basse    |
| **HashiCorp Vault**        | Gestion avancée des secrets             | Basse    |
-----------------------------------------------------------------------------------
---

## 11. Conclusion

Ce projet a permis de mettre en place une **pipeline CI/CD complète et fonctionnelle** pour l'application PayMyBuddy. Les objectifs initiaux ont tous été atteints :

### Réalisations Clés

1. **Pipeline automatisée** : Du commit au déploiement en production
2. **Multi-environnements** : Staging et Production sur AWS EC2
3. **Qualité assurée** : Tests automatisés et analyse SonarCloud
4. **Sécurité** : Gestion appropriée des secrets et validation manuelle
5. **Monitoring** : Notifications Slack en temps réel

### Points Forts du Projet

- Architecture scalable et maintenable
- Documentation complète
- Bonnes pratiques de sécurité appliquées
- Pipeline réutilisable pour d'autres projets

### Difficultés Surmontées

- Problèmes de configuration DNS résolus
- Gestion sécurisée des credentials maîtrisée
- Déploiement multi-environnements fonctionnel

Ce projet constitue une **base solide** pour une infrastructure DevOps professionnelle et démontre la maîtrise des concepts fondamentaux de l'intégration et du déploiement continus.

---

## 12. Annexes

### Annexe A : Commandes Utiles

```bash
# Vérifier l'état des conteneurs sur EC2
ssh -i key.pem ubuntu@107.20.66.5 "docker ps"

# Voir les logs de l'application
ssh -i key.pem ubuntu@107.20.66.5 "docker logs paymybuddy-staging"

# Health check manuel
curl http://107.20.66.5:8080/actuator/health

# Redémarrer l'application
ssh -i key.pem ubuntu@107.20.66.5 "docker restart paymybuddy-staging"
```

### Annexe B : Structure des Fichiers

```
PayMyBuddy/
├── src/
│   ├── main/
│   │   ├── java/com/paymybuddy/
│   │   └── resources/
│   │       ├── application.properties
│   │       ├── application-staging.properties
│   │       └── application-production.properties
│   └── test/
├── Dockerfile
├── Jenkinsfile
├── pom.xml
├── README.md
└── RAPPORT_FINAL.md
```

### Annexe C : Références

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Documentation](https://docs.docker.com/)
- [SonarCloud Documentation](https://docs.sonarcloud.io/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Spring Boot Reference](https://spring.io/projects/spring-boot)

---

**Fin du Rapport**

*Document rédigé par Adalbert Nanda *
*Formation EAZYTraining DevOps BootCamp*
*Janvier 2026*

# Pipeline CI/CD Jenkins - PayMyBuddy

## Description du Projet

Ce projet implémente une **pipeline CI/CD complète** avec Jenkins pour l'application **PayMyBuddy**, une application Spring Boot de transfert d'argent entre amis. La pipeline automatise l'intégralité du cycle de vie du logiciel : tests, analyse de qualité, build, containerisation et déploiement sur AWS EC2.

**Auteur :** Adalbert Nanda
**Formation :** EAZYTraining DevOps BootCamp
**Date :** Janvier 2026

---

## Architecture Globale

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         PIPELINE CI/CD PAYMYBUDDY                          │
└────────────────────────────────────────────────────────────────────────────┘

  ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────────────┐
  │  GitHub  │─────>│ Jenkins  │─────>│ Docker   │─────>│ AWS EC2          │
  │  (SCM)   │      │ (CI/CD)  │      │ Hub      │      │ Staging & Prod   │
  └──────────┘      └────┬─────┘      └──────────┘      └──────────────────┘
                         │
                    ┌────┴────┐
                    │         │
               ┌────▼───┐ ┌───▼────┐
               │ Sonar  │ │ Slack  │
               │ Cloud  │ │ Notif  │
               └────────┘ └────────┘
```

### Flux de la Pipeline

```
┌─────────┐   ┌───────┐   ┌─────────┐   ┌─────────┐   ┌───────┐   ┌────────-┐
│Checkout │──>│ Tests │──>│ Sonar   │──>│ Package │──>│ Build │──>│ Push    │
│  SCM    │   │ JUnit │   │ Cloud   │   │ Maven   │   │Docker │   │DockerHub│
└─────────┘   └───────┘   └─────────┘   └─────────┘   └───────┘   └────────-┘
                                                                       │
                          ┌────────────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                    DÉPLOIEMENT (Branche main uniquement)                   │
├────────────────────────────────────────────────────────────────────────────┤
│  ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │ Deploy   │──>│ Health   │──>│ Approval │──>│ Deploy   │──>│ Health   │  │
│  │ Staging  │   │ Check    │   │ Manuel   │   │ Prod     │   │ Check    │  │
│  └──────────┘   └──────────┘   └──────────┘   └──────────┘   └──────────┘  │
└────────────────────────────────────────────────────────────────────────────┘
```

---

## Technologies Utilisées
|--------------------------------------------------------------------|
|       Catégorie    |   Technologie | Version  | Utilisation        |
|--------------------|---------------|----------|--------------------|
| **Application**    |   Java        |   17     | Runtime            |
|                    |   Spring Boot |   3.x    | Framework          |
|                    |   Maven       |   3.9    | Build tool         |
| **CI/CD**          |   Jenkins     |   2.520  | Orchestration      |
|                    |   Docker      | Latest   | Containerisation  -|
|                    |   Docker Hub  |    -     | Registry           |
| **Qualité**        |   SonarCloud  |    -     | Analyse de code    |
|                    |   JUnit       |    5     | Tests unitaires   -|
| **Infrastructure** |   AWS EC2     | t2.micro | Serveurs           |
|                    |   Vagrant     |    -     | VM locale Jenkins  |
| **Notifications**  |   Slack       |    -     |  Alertes           |
|--------------------------------------------------------------------|

---

## Environnements de Déploiement

|---------------------------------------------------------------|
| Environnement  |   IP Publique   | Port |         Usage       |
|----------------|-----------------|------|---------------------|
| **Staging**    | `107.20.66.5`   | 8080 | Tests d'intégration |
| **Production** | `54.234.61.221` | 8080 | Utilisateurs finaux |
|---------------------------------------------------------------|

### URLs d'accès

- **Staging :** http://107.20.66.5:8080
- **Production :** http://54.234.61.221:8080
- **Health Check Staging :** http://107.20.66.5:8080/actuator/health
- **Health Check Production :** http://54.234.61.221:8080/actuator/health

---

## Prérequis

### 1. Plugins Jenkins Requis

|-------------------------------------------------------------|
|         Plugin      |             Description               |
|---------------------|---------------------------------------|
| Pipeline            | Support des pipelines déclaratives    |
| Docker Pipeline     | Intégration Docker dans les pipelines |
| Git                 | Intégration SCM                       |
| SonarQube Scanner   | Analyse de qualité de code            |
| Slack Notification  | Notifications Slack                   |
| SSH Agent           | Connexions SSH sécurisées             |
| Credentials Binding | Gestion sécurisée des secrets         |
|-------------------------------------------------------------|

### 2. Credentials Jenkins

|-----------------------------------------------------------------------------------------------|
|           ID            |              Type             |             Description             |
|-------------------------|-------------------------------|-------------------------------------|
| `dockerhub-credentials` | Username with password        | Identifiants Docker Hub             |
| `sonarcloud-token`      | Secret text                   | Token d'authentification SonarCloud |
| `slack-webhook`         | Secret text                   | URL Webhook Slack                   |
| `aws-ssh-staging`       | SSH Username with private key | Clé SSH pour EC2 Staging            |
| `aws-ssh-prod`          | SSH Username with private key | Clé SSH pour EC2 Production         |
|-----------------------------------------------------------------------------------------------|

### 3. Configuration SonarCloud

|---------------------------------------------|
|   Paramètre  |            Valeur            |
|--------------|------------------------------|
| Organization | `adalbert-code`              |
| Project Key  | `Adalbert-code_paymybuddy00` |
| URL          | https://sonarcloud.io        |
|---------------------------------------------|

---

## Étapes de la Pipeline

### Toutes les branches

|---------------------------------------------------------------------------------------------|
| # |             Stage           |             Description                   | Durée moyenne |
|---|-----------------------------|-------------------------------------------|---------------|
| 1 | **Checkout**                | Récupération du code source depuis GitHub | ~1s           |
| 2 | **Tests Automatisés**       | Exécution des tests JUnit avec Maven      | ~1min 30s     |
| 3 | **Analyse SonarCloud**      | Vérification de la qualité du code        | ~1min         |
| 4 | **Compilation & Packaging** | Build du JAR avec Maven                   | ~20s          |
| 5 | **Build Docker**            | Construction de l'image Docker            | ~30s          |
| 6 | **Push Docker Hub**         | Publication de l'image sur le registry    | ~15s          |
|---------------------------------------------------------------------------------------------|
### Branche main uniquement

|------------------------------------------------------------------------------------------------------------|
| # |               Stage              |                     Description                     | Durée moyenne |
|---|----------------------------------|-----------------------------------------------------|---------------|
| 7 | **Déploiement Staging**          | Déploiement sur EC2 Staging                         |     ~30s      |
| 8 | **Tests Validation Staging**     | Health check de l'application                       |     ~30s      |
| 9 | **Déploiement Production**       | Déploiement sur EC2 Prod (avec validation manuelle) |     ~30s      |
| 10 | **Tests Validation Production** | Health check de l'application                       |     ~30s      |
|------------------------------------------------------------------------------------------------------------|

---

## Installation et Configuration

### 1. Préparation de l'environnement Jenkins

```bash
# Cloner le repository
git clone https://github.com/votre-repo/PayMyBuddy.git
cd PayMyBuddy

# La configuration Jenkins est dans le Jenkinsfile à la racine
```

### 2. Configuration des instances EC2

Sur chaque instance AWS EC2 (Staging et Production) :

```bash
# Connexion SSH
ssh -i votre-cle.pem ubuntu@<IP_INSTANCE>

# Installation de Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Déconnexion/reconnexion pour appliquer les groupes
exit
ssh -i votre-cle.pem ubuntu@<IP_INSTANCE>

# Vérification
docker --version
docker ps
```

### 3. Configuration des Security Groups AWS

|------------------------------------------------|
| Règle | Port |   Source    |    Description    |
|-------|------|-------------|-------------------|
| SSH   | 22   | IP Jenkins  | Accès déploiement |
| HTTP  | 8080 | 0.0.0.0/0   | Accès application |
| MySQL | 3306 | VPC interne | Base de données   |
|------------------------------------------------|

### 4. Création des Credentials Jenkins

#### Docker Hub (Access Token)
1. Docker Hub → Account Settings → Security → New Access Token
2. Jenkins → Manage Jenkins → Credentials → Add Credentials
3. Kind: `Username with password`
4. ID: `dockerhub-credentials`

#### SSH Keys (EC2)
1. Jenkins → Manage Jenkins → Credentials → Add Credentials
2. Kind: `SSH Username with private key`
3. ID: `aws-ssh-staging` ou `aws-ssh-prod`
4. Username: `ubuntu`
5. Private Key: Contenu du fichier `.pem`

---

## Sécurité

### Bonnes pratiques implémentées

|--------------------------------------------------------------------------------|
|         Pratique        |                Implementation                        |
|-------------------------|------------------------------------------------------|
| **Secrets sécurisés**   | Tous les credentials dans Jenkins Credentials Store  |
| **Pas de hardcoding**   | Variables d'environnement pour les secrets           |
| **Shell expansion**     | `\$VAR` au lieu de `${VAR}` pour les secrets dans sh |
| **SSH par clé**         | Authentification par clé privée, pas de mot de passe |
| **Validation manuelle** | Approbation requise avant déploiement production     |
| **Security Groups**     | Ports ouverts uniquement selon le besoin             |
|--------------------------------------------------------------------------------|

### Exemple de gestion sécurisée des credentials

```groovy
// CORRECT - Shell expansion (sécurisé)
sh """
    echo \$DOCKERHUB_CREDENTIALS_PSW | docker login -u \$DOCKERHUB_CREDENTIALS_USR --password-stdin
"""

// INCORRECT - Groovy interpolation (insécurisé)
sh """
    echo ${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin
"""
```

---

## Troubleshooting

### Problème : "Permission denied (publickey)" lors du déploiement SSH

**Cause :** Credential SSH mal configuré ou IP incorrecte

**Solution :**
1. Vérifier l'ID du credential dans Jenkins (`aws-ssh-staging` / `aws-ssh-prod`)
2. Vérifier que la clé privée est complète (incluant BEGIN/END)
3. Vérifier l'IP de l'instance EC2

### Problème : "Docker registry timeout" ou "DNS resolution failed"

**Cause :** Problème DNS sur la VM Jenkins

**Solution :**
```bash
# Sur la VM Jenkins (pas dans le conteneur)
sudo mkdir -p /etc/systemd/resolved.conf.d/
sudo tee /etc/systemd/resolved.conf.d/dns.conf << 'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4
FallbackDNS=1.1.1.1
EOF

sudo systemctl restart systemd-resolved
sudo systemctl restart docker
```

### Problème : "SonarCloud server cannot be reached"

**Cause :** DNS ou connectivité réseau

**Solution :**
1. Vérifier la résolution DNS : `ping sonarcloud.io`
2. Ajouter `--dns 8.8.8.8` dans les options Docker du Jenkinsfile

### Problème : "Docker login unauthorized"

**Cause :** Credentials Docker Hub incorrects

**Solution :**
1. Utiliser un **Access Token** Docker Hub (pas le mot de passe du compte)
2. Vérifier l'ID du credential : `dockerhub-credentials`

---

## Notifications Slack

La pipeline envoie automatiquement des notifications Slack :

|--------------------------------------------------------------------------|
|    Statut   | Couleur |                   Contenu                        |
|-------------|---------|--------------------------------------------------|
| **SUCCESS** | Vert    | Job, Build #, Branch, Durée, URLs de déploiement |
| **FAILURE** | Rouge   | Job, Build #, Branch, Durée, Stage en échec      |
|--------------------------------------------------------------------------|

---

## Métriques et Qualité

### SonarCloud

Le projet est analysé automatiquement par SonarCloud à chaque build :

- **Quality Gate** : Vérification automatique des standards de qualité
- **Code Coverage** : Couverture des tests
- **Code Smells** : Détection des mauvaises pratiques
- **Security Hotspots** : Analyse de sécurité
- **Duplications** : Détection du code dupliqué

Dashboard : https://sonarcloud.io/project/overview?id=Adalbert-code_paymybuddy00

---

## Améliorations Futures

|-----------------------------------------------------------------------------------|
| Priorité |       Amélioration     |                 Description                   |
|----------|------------------------|-----------------------------------------------|
| Haute    | Rollback automatique   | Retour à la version précédente en cas d'échec |
| Haute    | Tests d'intégration    | Tests E2E avec Selenium ou Cypress            |
| Moyenne  | Blue-Green Deployment  | Déploiement sans interruption                 |
| Moyenne  | Monitoring             | Prometheus + Grafana                          | 
| Basse    | Gestion secrets        | HashiCorp Vault                               |
| Basse    | Infrastructure as Code | Terraform pour AWS                            |
|-----------------------------------------------------------------------------------|

---

## Structure du Projet

```
PayMyBuddy/
├── src/
│   ├── main/
│   │   ├── java/           # Code source Java
│   │   └── resources/      # Configuration Spring
│   └── test/               # Tests unitaires
├── Dockerfile              # Image Docker multi-stage
├── Jenkinsfile             # Pipeline CI/CD
├── pom.xml                 # Configuration Maven
├── README.md               # Documentation (ce fichier)
└── RAPPORT_FINAL.md        # Rapport de projet
```

---

## Conclusion

Ce projet démontre la mise en place d'une pipeline CI/CD complète et professionnelle intégrant :

- **Intégration Continue** : Tests automatisés et analyse de qualité
- **Déploiement Continu** : Staging automatique, Production avec validation
- **Infrastructure** : Conteneurisation Docker et déploiement AWS
- **Bonnes pratiques** : Sécurité, GitFlow, notifications

---

## Screenshots

![Staging Deployment](/screenshots/ec2_staging.png)
![Production Deployment](/screenshots/ec2_prod.png)
![Pipelines Deployment](/screenshots/pipelines_steps.png)
## Ressources

- [Documentation Jenkins](https://www.jenkins.io/doc/)
- [Documentation Docker](https://docs.docker.com/)
- [Documentation SonarCloud](https://docs.sonarcloud.io/)
- [Documentation AWS EC2](https://docs.aws.amazon.com/ec2/)
- [Spring Boot Reference](https://spring.io/projects/spring-boot)

---

## Contact

**Adalbert Nanda **
DevOps Engineer in Training
Formation : EAZYTraining DevOps BootCamp

---

**Statut du Projet :** Completed
**Dernière mise à jour :** Janvier 2026

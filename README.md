# Pipeline CI/CD Jenkins - PayMyBuddy

## 📋 Vue d'ensemble

Ce projet implémente une pipeline CI/CD complète avec Jenkins pour déployer l'application PayMyBuddy sur AWS EC2.

### Architecture de la Pipeline

```
GitLab → Jenkins → Docker Build → DockerHub → AWS EC2 (Staging/Production)
                ↓
         SonarCloud (Qualité du code)
                ↓
         Slack (Notifications)
```

## 🔧 Prérequis

### 1. Jenkins Plugins Installés
- ✅ Pipeline
- ✅ Docker Pipeline
- ✅ GitLab
- ✅ SonarQube Scanner
- ✅ Slack Notification
- ✅ SSH Agent

### 2. Credentials Configurés dans Jenkins

| ID                      | Type                          | Description            |
|-------------------------|-------------------------------|------------------------|
| `dockerhub-credentials` | Username with password        | DockerHub (adal2022)   |
| `sonarcloud-token`      | Secret text                   | Token SonarCloud       |
| `slack-webhook`         | Secret text                   | Webhook URL Slack      |
| `aws-ssh-staging`       | SSH Username with private key | Clé SSH EC2 Staging    |
| `aws-ssh-prod`          | SSH Username with private key | Clé SSH EC2 Production |

### 3. Ressources AWS

**Instance Staging:**
- IP: `3.208.15.55`
- Type: t2.micro
- OS: Ubuntu
- User: ubuntu

**Instance Production:**
- IP: `34.227.52.210`
- Type: t2.micro
- OS: Ubuntu
- User: ubuntu

**Sécurité Groups:**
- Port 22 (SSH) - ouvert depuis IP Jenkins
- Port 8080 (Application) - ouvert pour tests

### 4. Configuration SonarCloud

- Organization: `adalbert-code`
- Project Key: `Adalbert-code_paymybuddy00`
- Token: Configuré dans Jenkins credentials

## 🚀 Installation et Déploiement

### Étape 1: Préparer le Repo GitLab

```bash
# Cloner le repo
git clone https://gitlab.com/Adalbert-code/paymybuddy00.git
cd paymybuddy00

# Ajouter le Jenkinsfile et Dockerfile à la racine
cp /path/to/Jenkinsfile .
cp /path/to/Dockerfile .

# Commit et push
git add Jenkinsfile Dockerfile
git commit -m "Add CI/CD pipeline configuration"
git push origin main
```

### Étape 2: Configurer Jenkins Job

1. **Créer un nouveau Pipeline Job:**
   - New Item → Pipeline
   - Nom: `paymybuddy-cicd`

2. **Configuration Pipeline:**
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://gitlab.com/Adalbert-code/paymybuddy00.git`
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`

3. **Configuration Gitflow (si multibranch):**
   - Créer un Multibranch Pipeline
   - Branch sources: Git
   - Behaviors: Discover branches, PRs, etc.

### Étape 3: Préparer les Serveurs AWS EC2

**Sur chaque instance (Staging et Production):**

```bash
# Se connecter via SSH
ssh -i your-key.pem ubuntu@<IP_INSTANCE>

# Installer Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Se déconnecter et reconnecter pour appliquer les groupes
exit
ssh -i your-key.pem ubuntu@<IP_INSTANCE>

# Vérifier Docker
docker --version
docker ps
```

### Étape 4: Configurer SonarCloud

1. Aller sur https://sonarcloud.io
2. Se connecter avec GitLab
3. Importer le projet `paymybuddy00`
4. Générer un token
5. Ajouter le token dans Jenkins credentials

### Étape 5: Tester la Pipeline

```bash
# Dans Jenkins, lancer un build manuel
# Ou faire un commit pour déclencher automatiquement

git commit --allow-empty -m "Test pipeline"
git push origin main
```

## 📊 Étapes de la Pipeline

### Pour toutes les branches:
1. **Checkout** - Clone le code depuis GitLab
2. **Tests Automatisés** - Exécute les tests avec Maven
3. **Vérification Qualité** - Analyse SonarCloud
4. **Compilation & Packaging** - Build du JAR
5. **Build Docker** - Création de l'image Docker
6. **Push DockerHub** - Upload de l'image

### Pour la branche `main` uniquement:
7. **Déploiement Staging** - Déploie sur EC2 staging
8. **Tests Validation Staging** - Health check
9. **Déploiement Production** - Avec validation manuelle
10. **Tests Validation Production** - Health check
11. **Notification Slack** - Statut final

## 🔍 Vérifications Post-Déploiement

### Vérifier l'application Staging:
```bash
# Health check
curl http://3.208.15.55:8080/actuator/health

# Logs
ssh ubuntu@3.208.15.55 "docker logs paymybuddy-staging"
```

### Vérifier l'application Production:
```bash
# Health check
curl http://34.227.52.210:8080/actuator/health

# Logs
ssh ubuntu@34.227.52.210 "docker logs paymybuddy-prod"
```

## 🐛 Troubleshooting

### Erreur: "Docker build failed"
```bash
# Vérifier que le Dockerfile est bien à la racine
ls -la Dockerfile

# Vérifier les logs Jenkins
# Build → Console Output
```

### Erreur: "SSH connection refused"
```bash
# Vérifier que l'instance AWS est running
# Vérifier les Security Groups (port 22 ouvert)
# Vérifier la clé SSH dans Jenkins credentials
```

### Erreur: "SonarCloud analysis failed"
```bash
# Vérifier le token SonarCloud
# Vérifier les credentials Jenkins
# Vérifier que le projet existe sur SonarCloud
```

### Erreur: "Docker push unauthorized"
```bash
# Vérifier les credentials DockerHub dans Jenkins
# Tester manuellement: docker login
```

## 📱 Notifications Slack

Les notifications sont envoyées automatiquement à chaque build:
- ✅ SUCCESS - Message vert
- ❌ FAILURE - Message rouge
- Détails: Job, Build #, Branch, Durée

## 🔐 Sécurité

**Bonnes pratiques appliquées:**
- ✅ Credentials stockés dans Jenkins (pas hardcodés)
- ✅ SSH avec clés privées (pas de passwords)
- ✅ Tokens SonarCloud et DockerHub sécurisés
- ✅ Security Groups AWS restrictifs
- ✅ Validation manuelle avant déploiement prod

## 📈 Améliorations Futures

- [ ] Rollback automatique en cas d'échec
- [ ] Tests de charge
- [ ] Monitoring avec Prometheus/Grafana
- [ ] Blue-Green deployment
- [ ] Gestion des secrets avec Vault
- [ ] Multi-stage deployment (dev/staging/prod)

## 📚 Ressources

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Docker Documentation](https://docs.docker.com/)
- [SonarCloud Documentation](https://docs.sonarcloud.io/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

## ✨ Auteur

**Christelle** - DevOps Engineer in Training
- GitLab: [@Adalbert-code](https://gitlab.com/Adalbert-code)
- Formation: EAZYTraining DevOps BootCamp

---

**Statut du Lab:** ✅ Completed
**Date:** Décembre 2025

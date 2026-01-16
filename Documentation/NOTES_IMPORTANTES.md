# NOTES IMPORTANTES - À LIRE AVANT DE COMMENCER

## Configurations Critiques à Vérifier

### 1. Application Spring Boot

**Ton application DOIT avoir:**

#### a) Spring Boot Actuator (pour les health checks)

Ajoute dans ton `pom.xml` si pas déjà présent:

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

Dans `application.properties` ou `application.yml`:
```properties
management.endpoints.web.exposure.include=health,info
management.endpoint.health.show-details=always
```

#### b) Port 8080 configuré

Vérifie dans `application.properties`:
```properties
server.port=8080
```

### 2. Fichiers à Ajouter au Repo GitLab

**À la racine de ton projet, tu dois avoir:**

```
paymybuddy00/
├── Jenkinsfile          ← Le fichier pipeline
├── Dockerfile           ← Configuration Docker
├── pom.xml             ← Maven config
├── src/                ← Code source
│   └── main/
│       ├── java/
│       └── resources/
│           └── application.properties
└── README.md           ← Documentation (optionnel)
```

**Commandes pour ajouter les fichiers:**
```bash
cd /path/to/paymybuddy00
cp /path/downloaded/Jenkinsfile .
cp /path/downloaded/Dockerfile .
git add Jenkinsfile Dockerfile
git commit -m "Add CI/CD pipeline configuration"
git push origin main
```

### 3. Configuration SonarCloud dans Jenkins

**IMPORTANT:** Tu dois configurer le serveur SonarCloud dans Jenkins !

**Étapes:**
1. `Manage Jenkins` → `Configure System`
2. Scroll jusqu'à `SonarQube servers`
3. Clique `Add SonarQube`
4. Configuration:
   - **Name:** `SonarCloud` (exactement ce nom!)
   - **Server URL:** `https://sonarcloud.io`
   - **Server authentication token:** Sélectionne `sonarcloud-token`
5. **Save**

**Sans cette config, le stage SonarCloud va échouer!**

### 4. Préparer les Instances AWS EC2

**Sur chaque instance, Docker DOIT être installé:**

```bash
# Se connecter
ssh -i your-key.pem ubuntu@IP_INSTANCE

# Installer Docker
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter ubuntu au groupe docker
sudo usermod -aG docker ubuntu

# SE DÉCONNECTER et RECONNECTER
exit

# Reconnecter
ssh -i your-key.pem ubuntu@IP_INSTANCE

# Tester
docker ps  # Doit fonctionner sans sudo
```

### 5. Security Groups AWS

**STAGING (3.xxx.15.xx):**
- Port 22 (SSH) - Source: IP de ton Jenkins ou 0.0.0.0/0
- Port 8080 (HTTP) - Source: 0.0.0.0/0 (pour les tests)

**PRODUCTION (34.xxx.52.xxx):**
- Port 22 (SSH) - Source: IP de ton Jenkins ou 0.0.0.0/0
- Port 8080 (HTTP) - Source: 0.0.0.0/0

**Vérifier:**
AWS Console → EC2 → Instances → Sélectionne instance → Security Groups → Inbound rules

### 6. Test Manuel Docker sur EC2

**Avant de lancer la pipeline, teste manuellement:**

```bash
# Sur l'instance staging
ssh ubuntu@3.208.15.55

# Tester Docker pull depuis DockerHub
docker pull hello-world
docker run hello-world

# Si ça marche, c'est bon! ✅
```

## Ordre d'Exécution Recommandé

### Phase 1: Préparation (AVANT le premier build)
1. ✅ Vérifier application Spring Boot (Actuator configuré)
2. ✅ Ajouter Jenkinsfile et Dockerfile au repo
3. ✅ Configurer SonarCloud server dans Jenkins
4. ✅ Installer Docker sur instances EC2
5. ✅ Vérifier Security Groups AWS
6. ✅ Tester connexion SSH depuis Jenkins

### Phase 2: Premier Build
1. Créer le Pipeline Job dans Jenkins
2. Lancer un premier build
3. Observer les logs pour identifier les erreurs
4. Corriger au besoin

### Phase 3: Tests
1. Vérifier que l'app tourne sur staging
2. Tester le health check
3. Valider le déploiement en production
4. Vérifier les notifications Slack

## Problèmes Courants et Solutions

### Problème 1: "mvn: command not found" dans les tests
**Cause:** L'agent Docker Maven n'est pas utilisé
**Solution:** Vérifie que le stage utilise `agent { docker { image 'maven:3.8.6-openjdk-11' } }`

### Problème 2: "Docker login failed"
**Cause:** Credentials DockerHub incorrects
**Solution:** 
- Vérifie les credentials dans Jenkins
- ID doit être exactement: `dockerhub-credentials`
- Teste manuellement: `docker login -u adal2022`

### Problème 3: "SSH connection timeout"
**Cause:** Security Group ou instance arrêtée
**Solution:**
- Vérifie que l'instance est "running" sur AWS
- Vérifie Security Group port 22
- Teste: `ssh -i key.pem ubuntu@IP_INSTANCE`

### Problème 4: "SonarQube server not configured"
**Cause:** Server SonarCloud pas configuré dans Jenkins
**Solution:** Voir section "Configuration SonarCloud dans Jenkins"

### Problème 5: "curl: (7) Failed to connect"
**Cause:** Application non démarrée ou port fermé
**Solution:**
- SSH sur l'instance: `ssh ubuntu@IP`
- Vérifier les logs: `docker logs paymybuddy-staging`
- Vérifier le container: `docker ps`

## Checklist Avant Premier Build

- [ ] Jenkinsfile ajouté au repo GitLab
- [ ] Dockerfile ajouté au repo GitLab
- [ ] Actuator configuré dans l'application
- [ ] SonarCloud server configuré dans Jenkins
- [ ] Tous les credentials créés dans Jenkins:
  - [ ] dockerhub-credentials
  - [ ] sonarcloud-token
  - [ ] slack-webhook
  - [ ] aws-ssh-staging
  - [ ] aws-ssh-prod
- [ ] Docker installé sur staging EC2
- [ ] Docker installé sur production EC2
- [ ] Security Groups configurés
- [ ] Test SSH manuel réussi
- [ ] Pipeline Job créé dans Jenkins

## Adaptation pour Gitflow

**Pour supporter le modèle Gitflow demandé dans le lab:**

Le Jenkinsfile actuel vérifie déjà la branche avec `when { branch 'main' }`.

**Pour les autres branches (develop, feature/*):**
- Seuls ces stages s'exécutent:
  - Tests Automatisés
  - Vérification Qualité
  - Compilation et Packaging

**Les déploiements (staging/prod) sont EXCLUSIFS à la branche main.**

✅ Cela respecte les exigences du lab!

## Conseils Pro

1. **Commence simple**: Lance un premier build, observe les erreurs, corrige une par une
2. **Logs sont tes amis**: Console Output dans Jenkins montre TOUT
3. **Teste manuellement**: Avant d'automatiser, teste chaque commande manuellement
4. **Security Groups**: La cause #1 des problèmes SSH/HTTP
5. **Docker sur EC2**: Assure-toi que `ubuntu` peut utiliser Docker sans sudo

## Aide

Si tu bloques:
1. Lis les logs Jenkins (Console Output)
2. Identifie le stage qui échoue
3. Teste la commande manuellement
4. Vérifie les credentials/config

Bonne chance avec ton lab! 🚀

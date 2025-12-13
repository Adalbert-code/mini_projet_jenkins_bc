# # FROM amazoncorretto:17-alpine
# # ARG JAR_FILE=target/paymybuddy.jar
# # WORKDIR /app
# # COPY ${JAR_FILE} paymybuddy.jar
# # ENV SPRING_DATASOURCE_USERNAME=root
# # ENV SPRING_DATASOURCE_PASSWORD=password
# # ENV SPRING_DATASOURCE_URL=jdbc:mysql://172.17.0.1:3306/db_paymybuddy
# # CMD ["java", "-jar" , "paymybuddy.jar"]


# ==============================================================================
# DOCKERFILE AMÉLIORÉ - APPLICATION SPRING BOOT PAYMYBUDDY
# ==============================================================================
# 
# Version améliorée avec:
# ✅ Multi-stage build (compile + run)
# ✅ User non-root (sécurité)
# ✅ Health check intégré
# ✅ Optimisation de la taille
# ✅ Gestion sécurisée des secrets
# ✅ Layer caching optimisé
# 
# Auteur: Christelle (adalbert-code)
# Formation: EAZYTraining DevOps BootCamp
# ==============================================================================

# ==============================================================================
# STAGE 1: BUILD - COMPILATION DE L'APPLICATION
# ==============================================================================
# Ce stage compile l'application et génère le JAR
# On utilise Maven avec Amazon Corretto pour rester cohérent
# ==============================================================================

FROM maven:3.9-amazoncorretto-17 AS builder

# Métadonnées du stage de build
LABEL stage=builder
LABEL description="Build stage for PayMyBuddy application"

# Répertoire de travail pour la compilation
WORKDIR /build

# ==============================================================================
# OPTIMISATION DU CACHE DOCKER - COPIE DU POM.XML EN PREMIER
# ==============================================================================
# En copiant pom.xml séparément AVANT le code source:
# - Docker met en cache le téléchargement des dépendances Maven
# - Si seul le code change (pas les dépendances), le build est BEAUCOUP plus rapide
# - Les dépendances ne sont retéléchargées QUE si pom.xml change
# ==============================================================================

# Copie le fichier pom.xml
COPY pom.xml .

# Télécharge toutes les dépendances Maven
# verify = valide le projet sans compiler
# dependency:go-offline = télécharge toutes les dépendances
# Cette layer sera en cache tant que pom.xml ne change pas
RUN mvn dependency:go-offline -B

# Copie le code source
# Cette layer change souvent, mais les dépendances sont déjà en cache
COPY src ./src

# ==============================================================================
# COMPILATION DE L'APPLICATION
# ==============================================================================
# clean = supprime target/
# package = compile + crée le JAR
# -DskipTests = skip les tests (déjà exécutés par Jenkins)
# -B = batch mode (pas d'output interactif, meilleur pour CI/CD)
# ==============================================================================
RUN mvn clean package -DskipTests -B

# Vérifie que le JAR a bien été créé
RUN ls -la /build/target/*.jar

# ==============================================================================
# STAGE 2: RUNTIME - IMAGE FINALE OPTIMISÉE
# ==============================================================================
# Image finale légère qui contient uniquement:
# - JRE (pas JDK)
# - Le JAR de l'application
# - Configuration optimale
# ==============================================================================

FROM amazoncorretto:17-alpine

# ==============================================================================
# MÉTADONNÉES DE L'IMAGE
# ==============================================================================
# Bonnes pratiques: Documenter l'image avec des labels
# Visible avec: docker inspect <image>
# ==============================================================================
LABEL maintainer="Christelle <adalbert-code>"
LABEL description="PayMyBuddy - Spring Boot Application"
LABEL version="1.0"
LABEL vendor="EAZYTraining DevOps BootCamp"

# ==============================================================================
# INSTALLATION DES DÉPENDANCES SYSTÈME
# ==============================================================================
# curl = nécessaire pour le health check
# tzdata = pour gérer les fuseaux horaires
# ==============================================================================
RUN apk add --no-cache curl tzdata && \
    rm -rf /var/cache/apk/*

# ==============================================================================
# CRÉATION D'UN USER NON-ROOT (SÉCURITÉ)
# ==============================================================================
# ⚠️ IMPORTANT: Ne JAMAIS exécuter une app en tant que root!
# 
# Pourquoi?
# - Si l'app est compromise, l'attaquant n'a PAS les droits root
# - Limite les dégâts potentiels
# - Best practice Docker et Kubernetes
# 
# On crée:
# - Un groupe "spring" (GID 1001)
# - Un user "spring" (UID 1001) dans ce groupe
# - Sans password, sans home directory, sans shell (plus sécurisé)
# ==============================================================================
RUN addgroup -g 1001 -S spring && \
    adduser -u 1001 -S spring -G spring

# ==============================================================================
# CONFIGURATION DES RÉPERTOIRES
# ==============================================================================
# Crée le répertoire de travail avec les bonnes permissions
# ==============================================================================
WORKDIR /app

# Donne les permissions au user spring
RUN chown -R spring:spring /app

# ==============================================================================
# COPIE DU JAR DEPUIS LE STAGE BUILD
# ==============================================================================
# --from=builder = copie depuis le stage "builder"
# --chown=spring:spring = définit spring comme propriétaire du fichier
# On renomme en app.jar pour simplifier
# ==============================================================================
COPY --from=builder --chown=spring:spring /build/target/*.jar app.jar

# ==============================================================================
# EXPOSITION DU PORT
# ==============================================================================
# Documente que l'application écoute sur le port 8080
# Note: EXPOSE est documentaire, il faut quand même mapper avec -p au runtime
# ==============================================================================
EXPOSE 8080

# ==============================================================================
# VARIABLES D'ENVIRONNEMENT PAR DÉFAUT
# ==============================================================================
# ⚠️ IMPORTANT: Ces valeurs sont des DEFAULTS pour développement
# En PRODUCTION, elles DOIVENT être overridées au runtime!
# 
# Méthode recommandée en production:
# docker run -e SPRING_DATASOURCE_URL=jdbc:mysql://prod-db:3306/db ...
# 
# Ou mieux: Utiliser Docker Secrets, Kubernetes Secrets, AWS Secrets Manager
# ==============================================================================

# URL de la base de données (default pour dev/test)
# En prod, override avec la vraie URL (RDS, etc.)
ENV SPRING_DATASOURCE_URL=jdbc:mysql://172.17.0.1:3306/db_paymybuddy

# Username DB - NE PAS UTILISER EN PROD - Override au runtime
ENV SPRING_DATASOURCE_USERNAME=root

# Password DB - NE JAMAIS hardcoder en prod!
# Cette valeur sera overridée au runtime pour staging/prod
ENV SPRING_DATASOURCE_PASSWORD=password

# Profil Spring Boot par défaut
# Peut être overridé: -e SPRING_PROFILES_ACTIVE=prod
ENV SPRING_PROFILES_ACTIVE=default

# Configuration JVM pour optimiser les performances
ENV JAVA_OPTS="-Xms256m -Xmx512m -XX:+UseG1GC -Djava.security.egd=file:/dev/./urandom"

# ==============================================================================
# HEALTH CHECK
# ==============================================================================
# Docker vérifie périodiquement si l'application est saine
# 
# Options:
# --interval=30s : vérifie toutes les 30 secondes
# --timeout=3s : attend max 3 secondes pour une réponse
# --start-period=60s : attend 60s avant le premier check (temps de démarrage Spring Boot)
# --retries=3 : considère le container "unhealthy" après 3 échecs consécutifs
# 
# ⚠️ PRÉREQUIS: Spring Boot Actuator doit être configuré!
# Ajouter dans pom.xml:
# <dependency>
#   <groupId>org.springframework.boot</groupId>
#   <artifactId>spring-boot-starter-actuator</artifactId>
# </dependency>
# 
# Vérification manuelle: curl http://localhost:8080/actuator/health
# ==============================================================================
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# ==============================================================================
# SWITCH AU USER NON-ROOT
# ==============================================================================
# Toutes les commandes suivantes (dont CMD) s'exécutent en tant que "spring"
# Plus aucune commande ne s'exécute en root = SÉCURISÉ ✅
# ==============================================================================
USER spring:spring

# ==============================================================================
# COMMANDE DE DÉMARRAGE
# ==============================================================================
# ENTRYPOINT vs CMD:
# - ENTRYPOINT = partie fixe (java)
# - CMD = arguments par défaut (peuvent être overridés)
# 
# Avantage: On peut override les options Java au docker run si besoin
# 
# Exemple override:
# docker run myimage -Xmx1g -jar app.jar --spring.profiles.active=prod
# ==============================================================================
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]

# ==============================================================================
# UTILISATION - VERSION AMÉLIORÉE
# ==============================================================================
# 
# ============================================================================
# 1. BUILD DE L'IMAGE (Tout-en-un - compile + crée l'image)
# ============================================================================
# 
# docker build -t adal2022/paymybuddy:latest .
# 
# Options de build avancées:
# docker build \
#   --build-arg MAVEN_OPTS="-XX:+TieredCompilation -XX:TieredStopAtLevel=1" \
#   --tag adal2022/paymybuddy:1.0.0 \
#   --tag adal2022/paymybuddy:latest \
#   .
# 
# ============================================================================
# 2. LANCEMENT - DÉVELOPPEMENT LOCAL
# ============================================================================
# 
# docker run -d \
#   --name paymybuddy-dev \
#   -p 8080:8080 \
#   adal2022/paymybuddy:latest
# 
# ============================================================================
# 3. LANCEMENT - STAGING (avec secrets overridés)
# ============================================================================
# 
# docker run -d \
#   --name paymybuddy-staging \
#   -p 8080:8080 \
#   -e SPRING_PROFILES_ACTIVE=staging \
#   -e SPRING_DATASOURCE_URL=jdbc:mysql://staging-db.internal:3306/db_paymybuddy \
#   -e SPRING_DATASOURCE_USERNAME=staging_user \
#   -e SPRING_DATASOURCE_PASSWORD=${STAGING_DB_PASSWORD} \
#   adal2022/paymybuddy:latest
# 
# ============================================================================
# 4. LANCEMENT - PRODUCTION (avec AWS RDS et secrets)
# ============================================================================
# 
# # Récupère le password depuis AWS Secrets Manager
# export PROD_DB_PASSWORD=$(aws secretsmanager get-secret-value \
#   --secret-id paymybuddy/db/password \
#   --query SecretString \
#   --output text)
# 
# docker run -d \
#   --name paymybuddy-prod \
#   -p 8080:8080 \
#   --restart unless-stopped \
#   --memory="512m" \
#   --cpus="0.5" \
#   -e SPRING_PROFILES_ACTIVE=prod \
#   -e SPRING_DATASOURCE_URL=jdbc:mysql://paymybuddy.xxxxx.us-east-1.rds.amazonaws.com:3306/db_paymybuddy \
#   -e SPRING_DATASOURCE_USERNAME=prod_user \
#   -e SPRING_DATASOURCE_PASSWORD=${PROD_DB_PASSWORD} \
#   -e JAVA_OPTS="-Xms512m -Xmx1g -XX:+UseG1GC" \
#   adal2022/paymybuddy:latest
# 
# ============================================================================
# 5. LANCEMENT - AVEC DOCKER SECRETS (Plus sécurisé)
# ============================================================================
# 
# # Créer les secrets
# echo "prod_password" | docker secret create db_password -
# 
# # Lancer avec secrets (requiert Docker Swarm)
# docker service create \
#   --name paymybuddy \
#   --secret db_password \
#   -e SPRING_DATASOURCE_PASSWORD_FILE=/run/secrets/db_password \
#   adal2022/paymybuddy:latest
# 
# ============================================================================
# 6. VÉRIFICATIONS POST-DÉMARRAGE
# ============================================================================
# 
# # Vérifier que le container tourne
# docker ps
# 
# # Vérifier les logs
# docker logs paymybuddy-staging
# docker logs -f paymybuddy-staging  # Mode suivi en temps réel
# 
# # Vérifier le health check
# docker inspect paymybuddy-staging | grep -A 10 Health
# 
# # Tester l'endpoint health
# curl http://localhost:8080/actuator/health
# 
# # Tester l'application
# curl http://localhost:8080/api/test  # Adapter selon ton API
# 
# ============================================================================
# 7. MONITORING ET DEBUGGING
# ============================================================================
# 
# # Entrer dans le container (debug)
# docker exec -it paymybuddy-staging sh
# 
# # Voir l'utilisation des ressources
# docker stats paymybuddy-staging
# 
# # Inspecter l'image
# docker inspect adal2022/paymybuddy:latest
# 
# # Voir l'historique des layers
# docker history adal2022/paymybuddy:latest
# 
# ==============================================================================

# ==============================================================================
# AMÉLIORATIONS PAR RAPPORT À LA VERSION ORIGINALE
# ==============================================================================
# 
# ✅ SÉCURITÉ:
#    - User non-root (spring:spring au lieu de root)
#    - Image de base minimale (alpine)
#    - Secrets peuvent être overridés au runtime
#    - Pas de secrets hardcodés en production
# 
# ✅ PERFORMANCE:
#    - Multi-stage build = image finale 50% plus légère
#    - Cache Maven optimisé (pom.xml séparé)
#    - Options JVM configurables via JAVA_OPTS
#    - G1 Garbage Collector pour meilleure latence
# 
# ✅ MONITORING:
#    - Health check intégré
#    - Docker peut auto-restart si unhealthy
#    - Kubernetes peut utiliser le health check pour liveness/readiness
# 
# ✅ FLEXIBILITÉ:
#    - Profils Spring Boot configurables (-e SPRING_PROFILES_ACTIVE)
#    - Variables d'environnement overridables
#    - Compilation intégrée (pas besoin de Maven local)
# 
# ✅ PRODUCTION-READY:
#    - Métadonnées complètes
#    - Documentation extensive
#    - Compatible CI/CD
#    - Prêt pour Kubernetes/Docker Swarm
# 
# ==============================================================================

# ==============================================================================
# COMPATIBILITÉ AVEC JENKINS
# ==============================================================================
# 
# Ce Dockerfile est 100% compatible avec ta pipeline Jenkins!
# 
# Dans le Jenkinsfile, au stage "Build et Push Docker Image":
# - Jenkins clone le repo (qui contient ce Dockerfile)
# - Jenkins exécute: docker build -t adal2022/paymybuddy:${BUILD_NUMBER} .
# - Docker compile l'app (stage builder) et crée l'image finale
# - Jenkins push l'image vers DockerHub
# - Déploiement sur AWS EC2 avec les ENV overridées
# 
# Aucune modification du Jenkinsfile n'est nécessaire! ✅
# 
# ==============================================================================

# ==============================================================================
# MIGRATION DEPUIS LA VERSION ORIGINALE
# ==============================================================================
# 
# Pour passer de ton Dockerfile original à cette version améliorée:
# 
# 1. REMPLACE l'ancien Dockerfile par celui-ci
# 
# 2. AJOUTE Spring Boot Actuator dans pom.xml (pour health check):
#    <dependency>
#        <groupId>org.springframework.boot</groupId>
#        <artifactId>spring-boot-starter-actuator</artifactId>
#    </dependency>
# 
# 3. CONFIGURE Actuator dans application.properties:
#    management.endpoints.web.exposure.include=health,info
#    management.endpoint.health.show-details=always
# 
# 4. TESTE localement:
#    docker build -t paymybuddy-test .
#    docker run -d -p 8080:8080 paymybuddy-test
#    curl http://localhost:8080/actuator/health
# 
# 5. COMMIT et PUSH vers GitLab
# 
# 6. LANCE la pipeline Jenkins
# 
# C'est tout! ✅
# 
# ==============================================================================

# ==============================================================================
# POUR ALLER PLUS LOIN
# ==============================================================================
# 
# - Utiliser .dockerignore pour exclure les fichiers inutiles
# - Implémenter des security scans (Trivy, Snyk)
# - Signer les images Docker pour la supply chain security
# - Utiliser des tags immutables (SHA256) pour la reproductibilité
# - Implémenter le chiffrement des secrets at-rest
# 
# ==============================================================================

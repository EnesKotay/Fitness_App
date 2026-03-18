# ── Stage 1: Build ────────────────────────────────────────
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
# Bağımlılıkları önce indir (cache için — rootDirectory=backend olunca bu path doğru)
RUN mvn dependency:go-offline -q
COPY src/ ./src/
RUN mvn package -DskipTests -q

# ── Stage 2: Run ──────────────────────────────────────────
FROM registry.access.redhat.com/ubi9/openjdk-21:1.23
ENV LANGUAGE='en_US:en'

COPY --chown=185 --from=build /build/target/quarkus-app/lib/ /deployments/lib/
COPY --chown=185 --from=build /build/target/quarkus-app/*.jar /deployments/
COPY --chown=185 --from=build /build/target/quarkus-app/app/ /deployments/app/
COPY --chown=185 --from=build /build/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185
ENV JAVA_OPTS_APPEND="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager -Dquarkus.profile=prod"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"
ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]

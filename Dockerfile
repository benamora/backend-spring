# ---------- BUILD STAGE ----------
FROM maven:3.9.6-eclipse-temurin-17 AS build
WORKDIR /app

# Copy pom.xml first (better caching)
COPY pom.xml .
RUN mvn dependency:go-offline

# Copy source
COPY src ./src

# Build the jar
RUN mvn clean package -DskipTests


# ---------- RUNTIME STAGE ----------
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy exact jar name
COPY --from=build /app/target/backend-0.0.1-SNAPSHOT.jar app.jar

# App listens on 8082
EXPOSE 8082

# Run app
ENTRYPOINT ["java", "-jar", "app.jar"]

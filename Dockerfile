# AXA DevSecOps Reference: hardened multi-stage Dockerfile
#
# AXA controls applied:
# - CLDEV-CFG-01: minimal base image, non-root user, no unnecessary tools
# - CLDEV-CFG-01: read-only root filesystem (enforced in K8s manifest)
#
# Build stage: full JDK with Maven, used to compile and package the application.
# Runtime stage: distroless Java image. No shell, no package manager, no curl.
# Smallest possible attack surface.

# ============================================================================
# Stage 1: Build
# ============================================================================
FROM eclipse-temurin:17-jdk-alpine AS build

WORKDIR /workspace

# Copy build files first to leverage Docker layer caching
COPY pom.xml .
COPY src ./src

# Resolve dependencies and build the jar
RUN apk add --no-cache maven && \
    mvn -B -q dependency:resolve && \
    mvn -B -q package -DskipTests

# ============================================================================
# Stage 2: Runtime
# ============================================================================
# Distroless image: no shell, no apt, no curl. Just the JVM and the app.
# This dramatically reduces the attack surface compared to ubuntu or debian.
FROM gcr.io/distroless/java17-debian12:nonroot

# Image metadata (helps with SBOM and registry browsing)
LABEL org.opencontainers.image.title="AXA DevSecOps Reference"
LABEL org.opencontainers.image.description="Reference application for the AXA Secure SDLC training"
LABEL org.opencontainers.image.vendor="AXA Group Security"
LABEL org.opencontainers.image.source="https://github.com/axa-group/devsecops-reference"

# Use the nonroot user (UID 65532) baked into the distroless image.
# Even without an explicit USER directive, distroless:nonroot runs as non-root.
USER nonroot

# Copy only the built jar from the build stage
COPY --from=build /workspace/target/devsecops-reference-1.0.0.jar /app/application.jar

# Expose only the application port. No SSH, no management interfaces.
EXPOSE 8080

# Use exec form so signals reach the JVM correctly (graceful shutdown)
ENTRYPOINT ["java", "-jar", "/app/application.jar"]

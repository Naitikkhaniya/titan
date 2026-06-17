################################################################################
# Titan Backend - Dockerfile
#
# Purpose: Build a production-ready Docker image for the Titan backend
#          Express.js service running on Node.js 20 Alpine Linux
#
# Build: docker build -t titan-backend:1.0 .
# Run:   docker run -p 3000:3000 titan-backend:1.0
#
# Image Details:
#   - Base: Node.js 20-Alpine (lightweight, ~150MB)
#   - Size: ~200MB (with dependencies)
#   - OS: Alpine Linux (minimal attack surface)
#
# Security Features:
#   - Non-root user for running application
#   - Multi-stage build ready (for future optimization)
#   - No unnecessary files in final image
#   - Minimal base image
#
# Author: Titan DevOps Platform
# Last Modified: 2026-06-17
################################################################################

################################################################################
# Stage 1: Base Image Selection
################################################################################

# FROM instruction: Specifies the base image to build upon
# 
# node:20-alpine means:
#   - node: Official Node.js image from Docker Hub
#   - 20: Major version of Node.js (stable LTS version as of 2026)
#   - alpine: Alpine Linux distribution (minimal, ~5MB base)
#
# Why Alpine?
#   - Smaller image size (~150MB vs ~900MB for full Node.js)
#   - Faster downloads and container startup
#   - Smaller attack surface
#   - Sufficient for production workloads
#   - Standard for containerized Node.js applications
#
FROM node:20-alpine

################################################################################
# Stage 2: Metadata and Labels
################################################################################

# LABEL: Add metadata to the image for documentation and organization
#
# Labels help with:
#   - Image identification
#   - Version tracking
#   - Organization and searching
#   - CI/CD pipeline integration
#
LABEL maintainer="Titan DevOps Platform"
LABEL version="1.0"
LABEL description="Titan Backend Express.js Service"
LABEL org.opencontainers.image.source="https://github.com/Naitikkhaniya/titan"

################################################################################
# Stage 3: Environment Variables
################################################################################

# ENV: Set environment variables that will be available in the container
#
# These variables:
#   - Configure Node.js behavior
#   - Optimize production performance
#   - Set default application configuration
#
# NODE_ENV=production tells Node.js to:
#   - Skip development dependencies
#   - Enable performance optimizations
#   - Disable debug logging
#
ENV NODE_ENV=production \
    NODE_OPTIONS="--max-old-space-size=256"

################################################################################
# Stage 4: Working Directory
################################################################################

# WORKDIR: Sets the working directory inside the container
#
# Purpose: All subsequent RUN, COPY, ADD, CMD, ENTRYPOINT instructions
#          will be executed in this directory
#
# /app/backend is chosen because:
#   - Follows standard Linux application structure
#   - Matches local development structure (/Titan/app/backend)
#   - Clear separation from system directories
#   - Mirrors project organization
#
# If directory doesn't exist, Docker creates it automatically
#
WORKDIR /app/backend

################################################################################
# Stage 5: Copy Package Files (Dependency Layer)
################################################################################

# COPY: Copy files from host machine to container
#
# Syntax: COPY <source on host> <destination in container>
#
# Why copy package files FIRST?
#   - Docker builds images in layers
#   - Each layer is cached independently
#   - If application code changes but package.json doesn't:
#     * Docker skips npm install (uses cached layer)
#     * Build is much faster
#   - If package.json changes:
#     * Docker rebuilds npm install layer
#     * Application layer code change doesn't affect dependency cache
#
# This is a critical optimization technique called "layer caching"
#
# Copy both files:
#   - package.json: Project metadata and dependencies list
#   - package-lock.json: Locked dependency versions (ensures reproducibility)
#
COPY package.json package-lock.json ./

################################################################################
# Stage 6: Install Dependencies
################################################################################

# RUN: Execute a command inside the container during build
#
# npm ci (clean install) is preferred over npm install because:
#   - npm ci reads exact versions from package-lock.json
#   - npm install may update versions (not reproducible)
#   - npm ci is optimized for CI/CD and Docker builds
#   - Ensures exactly the same dependencies every time
#
# --only=production flag means:
#   - Only install dependencies listed in "dependencies"
#   - Skip "devDependencies" (reduce image size)
#   - In our case, no devDependencies, but good practice
#
# Production image should NEVER contain development tools:
#   - Reduces image size
#   - Reduces attack surface
#   - Faster container startup
#   - Lower memory usage
#
RUN npm ci --only=production

################################################################################
# Stage 7: Copy Application Source Code
################################################################################

# COPY: Copy application source code into container
#
# Syntax: COPY <source on host> <destination in container>
#
# Copying . (current directory) copies all files EXCEPT:
#   - Files listed in .dockerignore (if it exists)
#   - .git directory
#   - node_modules (we installed those already)
#
# Why copy source code AFTER dependencies?
#   - Application code changes frequently
#   - Dependencies change infrequently
#   - If we copied source first, every code change would invalidate
#     the dependency cache, making builds slow
#   - This ordering ensures optimal layer caching
#
# Layer ordering (source before dependencies would be BAD):
#   COPY . .              # Layer 1: Application code (changes frequently)
#   RUN npm ci            # Layer 2: Dependencies (cached, but rebuilt every time!)
#
# Correct layer ordering (dependencies before source):
#   COPY package*.json .  # Layer 1: Dependencies list (changes rarely)
#   RUN npm ci            # Layer 2: Dependencies (cached when possible)
#   COPY . .              # Layer 3: Application code (changes frequently)
#
COPY . .

################################################################################
# Stage 8: Create Non-Root User
################################################################################

# RUN: Create a dedicated user for running the application
#
# Why NOT run as root?
#   - Security best practice
#   - If container is compromised, attacker has limited access
#   - Root access could allow modification of system files
#   - Production systems should run with least privilege
#
# addgroup -S titan:
#   - -S: Create system group (not for human users)
#   - titan: Group name
#
# adduser -S:
#   - -S: Create system user (not for human users)
#   - -G titan: Add user to titan group
#   - -h /app/backend: Set home directory
#   - titan: Username
#
RUN addgroup -S titan && \
    adduser -S -G titan -h /app/backend titan

################################################################################
# Stage 9: Set File Ownership
################################################################################

# RUN: Change ownership of application files to the new user
#
# chown -R titan:titan .:
#   - -R: Recursive (all files and directories)
#   - titan:titan: Change to user:group
#   - .: Current directory (/app/backend)
#
# Why is ownership important?
#   - Ensures the non-root user can read the files
#   - Prevents permission denied errors at runtime
#   - Applies principle of least privilege
#
RUN chown -R titan:titan .

################################################################################
# Stage 10: Switch to Non-Root User
################################################################################

# USER: Set the user context for subsequent commands and container execution
#
# Syntax: USER <username or UID>
#
# This means:
#   - All subsequent RUN commands execute as 'titan' user
#   - The container will START as 'titan' user
#   - Application runs with limited privileges
#
# Security implications:
#   - If container is compromised, attacker has 'titan' access only
#   - Cannot modify system files or install packages
#   - Greatly reduces potential damage
#
USER titan

################################################################################
# Stage 11: Expose Port
################################################################################

# EXPOSE: Document which port the application listens on
#
# Important: EXPOSE does NOT actually publish the port
#   - It's documentation for developers and orchestrators
#   - Port is only published when running with -p flag
#   - docker run -p 3000:3000 (maps host:container)
#
# Format: EXPOSE <port>
#
# When would EXPOSE be used?
#   - Docker Compose reads EXPOSE to map ports automatically
#   - Docker Swarm uses EXPOSE for service discovery
#   - Kubernetes infers port from EXPOSE
#   - Developers see which ports are used
#
# The actual port mapping happens at runtime:
#   - docker run -p 3000:3000 (host port 3000 → container port 3000)
#   - docker run -p 8000:3000 (host port 8000 → container port 3000)
#   - EXPOSE just declares that the app uses port 3000
#
EXPOSE 3000

################################################################################
# Stage 12: Health Check (Optional but Recommended)
################################################################################

# HEALTHCHECK: Define how Docker determines if container is healthy
#
# Purpose:
#   - Docker can automatically restart unhealthy containers
#   - Orchestrators (Kubernetes, Swarm) can replace failed containers
#   - Monitoring systems get container health status
#
# Syntax: HEALTHCHECK [OPTIONS] CMD <command>
#
# Options explained:
#   - --interval=30s: Check health every 30 seconds
#   - --timeout=5s: If check takes >5s, assume failed
#   - --start-period=5s: Grace period before first check
#   - --retries=3: Mark unhealthy after 3 failed checks
#
# The CMD:
#   - curl -f http://localhost:3000/health: Call health endpoint
#   - Exit status 0 = healthy, non-zero = unhealthy
#   - curl -f: Fail if HTTP status is not 2xx/3xx
#
# Example flow:
#   - Start container
#   - Wait 5 seconds (start-period)
#   - Every 30 seconds, curl http://localhost:3000/health
#   - If curl fails or times out (>5s), increment failure count
#   - After 3 consecutive failures, mark container unhealthy
#   - Docker or orchestrator can restart unhealthy container
#
# Note: curl is not available in Alpine by default, so this is optional
# For production, install curl or use wget:
#   RUN apk add --no-cache curl
#
# For now, we'll skip HEALTHCHECK and add it when curl is available
# HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
#   CMD curl -f http://localhost:3000/health || exit 1

################################################################################
# Stage 13: Start Application
################################################################################

# CMD: Default command to run when container starts
#
# Syntax: CMD ["executable", "param1", "param2", ...]
#         This is "exec form" (recommended, direct process execution)
#
# Alternative syntax (shell form, NOT recommended for containers):
#   CMD npm start
#   ^ This runs "npm start" inside a shell, adding overhead
#
# Why use exec form?
#   - Direct process execution (no shell wrapper)
#   - PID 1 is the application (receives signals correctly)
#   - Graceful shutdown works properly
#   - Faster startup
#
# When container is run:
#   1. Docker creates container from image
#   2. Docker executes CMD: ["npm", "start"]
#   3. npm starts the Node.js server
#   4. Server listens on 0.0.0.0:3000
#   5. Container runs until process exits
#
# To override the CMD at runtime:
#   docker run titan-backend:1.0 npm run dev  # Runs dev instead of start
#   docker run titan-backend:1.0 /bin/sh      # Interactive shell
#
# Signal handling (important for graceful shutdown):
#   - docker stop sends SIGTERM to PID 1
#   - If PID 1 is npm process, it receives signal
#   - npm can then gracefully shut down the server
#   - If using shell form, shell receives signal (npm doesn't), no graceful shutdown
#
CMD ["npm", "start"]

################################################################################
# Docker Build & Run Reference
################################################################################

# Build the image:
#   docker build -t titan-backend:1.0 .
#   docker build -t titan-backend:latest .
#   docker build -t my-registry.com/titan-backend:1.0 .
#
# Run the container:
#   docker run -p 3000:3000 titan-backend:1.0
#   docker run -p 8000:3000 titan-backend:1.0  (different host port)
#   docker run -d -p 3000:3000 titan-backend:1.0  (detached, background)
#   docker run -e NODE_ENV=development -p 3000:3000 titan-backend:1.0
#
# View image details:
#   docker images
#   docker inspect titan-backend:1.0
#   docker history titan-backend:1.0  (show layers)
#
# View container logs:
#   docker logs <container-id>
#   docker logs -f <container-id>  (follow/tail logs)
#
# Stop and remove:
#   docker stop <container-id>
#   docker rm <container-id>
#   docker rmi titan-backend:1.0  (remove image)
#
################################################################################

# Docker Basics for Titan

This document explains Docker concepts essential for understanding and working with the Titan backend containerization.

## What is Docker?

Docker is a containerization platform that packages applications and their dependencies into a standardized unit called a **container**. It ensures that applications run consistently across different environments (local machine, server, cloud).

### Key Problem It Solves

**Without Docker**:
- Developer installs Node.js 20, runs app → works
- Operations installs Node.js 18, runs app → breaks
- Different Linux versions have different libraries → "works on my machine" syndrome

**With Docker**:
- Application and ALL dependencies packaged together
- Same container runs identically on any system
- Eliminates environment differences

---

## Docker Image vs Docker Container

### Docker Image

A **Docker image** is a blueprint or template for creating containers.

**Characteristics**:
- Read-only template containing the complete application stack
- Includes OS, libraries, dependencies, and application code
- Stored as layers (like git commits)
- Immutable (once built, cannot be changed)
- Portable (can be moved between systems)
- Reusable (many containers can be created from one image)

**Analogy**: A Docker image is like a computer class diagram (blueprint), specifying what to include.

**Size**: For Titan backend:
- Base node:20-alpine: ~150MB
- With npm packages: ~200MB
- Layer-based (each component is a separate layer)

### Docker Container

A **Docker container** is a running instance of a Docker image.

**Characteristics**:
- Runtime environment based on an image
- Writable layer on top of read-only image layers
- Isolated from other containers
- Can be started, stopped, restarted
- Temporary (data is lost when container is removed)
- Can be created from the same image

**Analogy**: A Docker container is like an instance of the class (actual object created from blueprint).

**Lifecycle**:
```
Created → Running → Stopped → Removed
```

**Multiple containers from one image**:
```
Image: titan-backend:1.0
├── Container 1 (running on :3000)
├── Container 2 (running on :3001)
└── Container 3 (stopped)
```

---

## Docker Build Process

The build process creates a Docker image from a Dockerfile.

### How Docker Builds Images

1. **Parse Dockerfile**: Read instructions sequentially
2. **Create Layers**: Each instruction creates a new layer
3. **Execute Instructions**: Run commands, copy files
4. **Cache Layers**: Store completed layers for reuse
5. **Tag Image**: Assign name and version

### Build Layers (Key Concept)

Docker builds images as a stack of layers. Each instruction creates a new layer.

**Layer Stack** (bottom to top):

```
Layer 5 (Top): CMD npm start
├─ Layer 4: USER titan
├─ Layer 3: COPY . .  (application code)
├─ Layer 2: RUN npm ci  (node_modules)
├─ Layer 1: COPY package.json .  (dependencies list)
└─ Layer 0 (Base): FROM node:20-alpine
```

**Why Layers Matter**:

Each layer is independently cached. When rebuilding:

```
Scenario 1: Only app code changed
┌─────────────────────────────────┐
│ Build cache hit (reuse)         │
├─────────────────────────────────┤
│ COPY package.json . (cached)    │ ✓ Use cached layer
│ RUN npm ci (cached)             │ ✓ Use cached layer
├─────────────────────────────────┤
│ COPY . . (cache miss)           │ ✗ Rebuild this layer
│ CMD npm start (must rebuild)    │ ✗ Rebuild dependent layers
└─────────────────────────────────┘
Result: Fast rebuild (skip dependencies)

Scenario 2: package.json changed
┌─────────────────────────────────┐
│ Build cache hit (reuse)         │
├─────────────────────────────────┤
│ COPY package.json . (cache hit) │ ✓ Use cached layer
│ RUN npm ci (cache MISS)         │ ✗ Rebuild (dependencies changed)
├─────────────────────────────────┤
│ COPY . . (must rebuild)         │ ✗ Rebuild
│ CMD npm start (must rebuild)    │ ✗ Rebuild
└─────────────────────────────────┘
Result: Moderate rebuild (reinstall dependencies)
```

### Build Command Anatomy

```bash
docker build -t titan-backend:1.0 .
│      │     │ └─ tag/name:version
│      │     └─ assign name and version to image
│      └─ subcommand (build an image)
└─ Docker CLI
```

**Common build variations**:

```bash
# Build with specific tag
docker build -t titan-backend:1.0 .

# Build with latest tag (default version)
docker build -t titan-backend:latest .

# Build with registry path
docker build -t docker.io/myrepo/titan-backend:1.0 .

# Build with multiple tags
docker build -t titan-backend:1.0 -t titan-backend:latest .

# Build with build arguments
docker build --build-arg NODE_ENV=production -t titan-backend:1.0 .

# Show build steps (verbose)
docker build --progress=plain -t titan-backend:1.0 .
```

### Build Output Example

```
Step 1/13 : FROM node:20-alpine
 ---> abc123def456  (pulling or using cached image)

Step 2/13 : LABEL maintainer="Titan DevOps Platform"
 ---> Running in temp_container_123
 ---> xyz789mno012  (new layer created)

Step 3/13 : ENV NODE_ENV=production ...
 ---> Running in temp_container_456
 ---> abc123def789  (new layer created)

...continuing...

Step 13/13 : CMD ["npm", "start"]
 ---> Running in temp_container_789
 ---> final_image_id_1234567890ab
 
Successfully built final_image_id_1234567890ab
Successfully tagged titan-backend:1.0
```

---

## Docker Run Process

The run process creates and starts a container from an image.

### How Docker Runs Containers

1. **Create Container**: Instantiate image with writable layer
2. **Set Up Networking**: Assign virtual network interface
3. **Mount Volumes**: Attach storage if specified
4. **Configure Environment**: Set env vars, ports
5. **Execute CMD**: Start the application process

### Run Command Anatomy

```bash
docker run -p 3000:3000 -e NODE_ENV=production titan-backend:1.0
│      │   │               │                      │
│      │   │               │                      └─ image to run
│      │   │               └─ environment variable
│      │   └─ port mapping (see next section)
│      └─ subcommand (create and run container)
└─ Docker CLI
```

### Container Lifecycle

```
docker run
    ↓
[Create container with writable layer]
    ↓
[Set up networking and mounts]
    ↓
[Execute CMD from image]
    ↓
Application running (PID 1)
    ↓
docker stop (send SIGTERM)
    ↓
[Graceful shutdown]
    ↓
docker rm (remove container)
```

### Common Run Options

| Option | Purpose | Example |
|--------|---------|---------|
| `-d` | Detached (background) | `docker run -d ...` |
| `-p` | Port mapping | `docker run -p 8000:3000 ...` |
| `-e` | Environment variable | `docker run -e NODE_ENV=prod ...` |
| `-v` | Volume mount | `docker run -v /data:/app/data ...` |
| `--name` | Container name | `docker run --name my-app ...` |
| `-it` | Interactive terminal | `docker run -it ...` (for debugging) |
| `--rm` | Auto-remove on exit | `docker run --rm ...` |
| `-m` | Memory limit | `docker run -m 512m ...` |

### Run Examples

**Basic run** (foreground, shows logs):
```bash
docker run -p 3000:3000 titan-backend:1.0
# See all console output
# Press Ctrl+C to stop
```

**Detached run** (background):
```bash
docker run -d -p 3000:3000 --name titan-api titan-backend:1.0
# Container runs in background
# Returns container ID
```

**With environment variables**:
```bash
docker run -d \
  -p 3000:3000 \
  -e NODE_ENV=production \
  -e PORT=3000 \
  --name titan-api \
  titan-backend:1.0
```

**With volume** (persistent storage):
```bash
docker run -d \
  -p 3000:3000 \
  -v /data/logs:/app/logs \
  --name titan-api \
  titan-backend:1.0
# Logs written to container /app/logs
# Persisted on host at /data/logs
```

---

## Port Mapping

Port mapping connects container ports to host ports so external traffic can reach the application.

### The Problem

- Container has isolated networking (virtual network interface)
- Host machine cannot directly access container's port 3000
- Need to "map" host port to container port

### Port Mapping Syntax

```
docker run -p <host-port>:<container-port> <image>
        │    │            │                 │
        │    │            └─ port INSIDE container (from EXPOSE)
        │    └─ port on HOST machine (what you connect to)
        └─ map ports
```

### Port Mapping Examples

**Default mapping** (1:1 mapping):
```bash
docker run -p 3000:3000 titan-backend:1.0
# Host port 3000 → Container port 3000
# Connect with: curl http://localhost:3000/
```

**Different host port**:
```bash
docker run -p 8000:3000 titan-backend:1.0
# Host port 8000 → Container port 3000
# Connect with: curl http://localhost:8000/
```

**Multiple port mappings**:
```bash
docker run -p 3000:3000 -p 9000:3000 titan-backend:1.0
# Both ports map to container port 3000
# Access on: localhost:3000 or localhost:9000
```

**Random port assignment**:
```bash
docker run -p 3000 titan-backend:1.0
# Docker assigns random host port (e.g., 32768)
# Check with: docker ps
```

### Port Mapping Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    HOST MACHINE                         │
│  localhost:3000 → [Docker Port Mapper] → Container     │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│               DOCKER CONTAINER                          │
│   Application listening on 0.0.0.0:3000                │
└─────────────────────────────────────────────────────────┘

Traffic flow:
1. Client connects to localhost:3000 on host
2. Docker port mapper intercepts the connection
3. Traffic forwarded to container port 3000
4. Application receives request
5. Response sent back through port mapper
6. Client receives response
```

### EXPOSE vs Port Mapping

**EXPOSE** (in Dockerfile):
```dockerfile
EXPOSE 3000
# Documentation: "This app uses port 3000"
# Does NOT publish the port
# Only maps in docker-compose or orchestrators
```

**Port Mapping** (in run command):
```bash
docker run -p 3000:3000  # Actually publishes the port
# EXPOSE is just documentation
# Port mapping at runtime is what matters
```

---

## Dockerfile Instructions Reference

### Instruction Hierarchy

```
FROM          # Base image (MUST be first)
│
LABEL         # Metadata (optional)
│
ENV           # Environment variables
│
WORKDIR       # Working directory
│
COPY/ADD      # Copy files from host
│
RUN           # Execute commands
│
USER          # Switch user context
│
EXPOSE        # Document ports (documentation only)
│
CMD           # Default command to run
ENTRYPOINT    # Container entry point
```

### Common Instructions

#### FROM

```dockerfile
FROM node:20-alpine
# Sets base image
# Must be first (except ARG)
# Can appear multiple times (multi-stage builds)
```

**Purpose**: Specify the base image to build upon.

#### LABEL

```dockerfile
LABEL version="1.0"
LABEL maintainer="email@example.com"
# Add metadata to image
# Useful for organization and automation
```

**Purpose**: Add searchable metadata to the image.

#### ENV

```dockerfile
ENV NODE_ENV=production
ENV PORT=3000
# Set environment variables
# Available in container at runtime
# Can be overridden with -e flag
```

**Purpose**: Set environment variables in the image.

#### WORKDIR

```dockerfile
WORKDIR /app/backend
# Set working directory
# Subsequent commands run here
# Creates directory if doesn't exist
```

**Purpose**: Specify the directory where commands run.

#### COPY

```dockerfile
COPY package.json .
COPY . .
# Copy files from host to container
# First argument: host path
# Second argument: container path
# Use . as relative path
```

**Purpose**: Copy files from build host into image.

#### ADD

```dockerfile
ADD file.tar.gz .
# Like COPY but can handle:
#   - Automatically extract tar files
#   - URLs (though COPY is preferred)
# Generally use COPY for clarity
```

**Purpose**: Copy files or extract archives (use COPY in most cases).

#### RUN

```dockerfile
RUN npm ci
RUN apk add --no-cache curl
# Execute command during build
# Creates new layer
# Commonly used for:
#   - Installing packages
#   - Building application
#   - Creating users/directories
```

**Purpose**: Execute commands during image build.

#### EXPOSE

```dockerfile
EXPOSE 3000
EXPOSE 3000 8080
# Document which ports app uses
# Does NOT publish ports
# Use docker run -p to actually publish
```

**Purpose**: Document port usage (metadata).

#### USER

```dockerfile
USER node
USER 1000  # UID
# Set user for subsequent commands
# Set user for container execution
# For security (don't run as root)
```

**Purpose**: Run container as specific user.

#### CMD

```dockerfile
CMD ["npm", "start"]        # exec form (recommended)
CMD npm start               # shell form (not recommended)
# Default command when container starts
# Can be overridden at runtime
# Only last CMD is used (can't have multiple)
```

**Purpose**: Set default command to run.

#### ENTRYPOINT

```dockerfile
ENTRYPOINT ["npm", "start"]
# Similar to CMD but harder to override
# Commonly combined with CMD:
#   ENTRYPOINT ["npm"]
#   CMD ["start"]          # npm start
```

**Purpose**: Configure container to run as executable.

---

## Building and Running Titan Backend

### Step 1: Build the Image

```bash
cd /path/to/Titan/app/backend

# Build image with tag
docker build -t titan-backend:1.0 .

# Verify image was created
docker images
# Should see: titan-backend | 1.0 | <image-id> | <size>
```

### Step 2: Run the Container

```bash
# Run in foreground (see logs)
docker run -p 3000:3000 titan-backend:1.0

# Or run in background
docker run -d -p 3000:3000 --name titan-api titan-backend:1.0
```

### Step 3: Test the Service

```bash
# Test root endpoint
curl http://localhost:3000/

# Test health endpoint
curl http://localhost:3000/health

# Pretty print JSON
curl -s http://localhost:3000/health | jq .
```

### Step 4: View Logs

```bash
# Foreground container: see logs in terminal
# Background container: view logs with

docker logs titan-api          # View logs
docker logs -f titan-api       # Follow logs (like tail -f)
docker logs --tail 50 titan-api # Last 50 lines
```

### Step 5: Stop Container

```bash
# If running in background
docker stop titan-api

# Remove container
docker rm titan-api

# Or in one command
docker rm -f titan-api
```

---

## Docker Best Practices

### 1. Layer Caching Optimization

**Bad** (inefficient):
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY . .                # Copy code first (changes frequently)
RUN npm ci              # Install packages (cached but rebuilt every time)
CMD ["npm", "start"]
```

**Good** (optimized):
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json .     # Copy dependencies first (changes rarely)
RUN npm ci              # Install packages (cached effectively)
COPY . .                # Copy code last (changes frequently)
CMD ["npm", "start"]
```

### 2. Use Minimal Base Images

| Base Image | Size | Use Case |
|-----------|------|----------|
| node:20 | ~900MB | Development |
| node:20-alpine | ~150MB | Production |
| node:20-slim | ~200MB | Middle ground |

Alpine is ideal for production.

### 3. Non-Root User

```dockerfile
# Bad (security risk)
CMD ["npm", "start"]  # Runs as root

# Good (secure)
RUN useradd -m app
USER app
CMD ["npm", "start"]  # Runs as app user
```

### 4. Explicit Versions

```dockerfile
# Bad (unpredictable)
FROM node:20         # Could update unexpectedly

# Good (reproducible)
FROM node:20.11.0-alpine  # Specific version
```

### 5. .dockerignore File

```
.git
node_modules
.DS_Store
.env.local
*.log
```

Prevents unnecessary files from being copied into image.

### 6. Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1
```

Allows Docker/orchestrators to detect unhealthy containers.

### 7. Multi-Stage Builds

For optimization (not covered in this basic setup):

```dockerfile
# Stage 1: Build
FROM node:20 AS builder
COPY . .
RUN npm ci && npm run build

# Stage 2: Runtime (smaller)
FROM node:20-alpine
COPY --from=builder /app/dist ./
CMD ["npm", "start"]
```

---

## Troubleshooting

### Container won't start

```bash
# Check logs
docker logs <container-id>

# Run in foreground to see errors
docker run -p 3000:3000 titan-backend:1.0
```

### Port already in use

```bash
# Check what's using port 3000
lsof -i :3000

# Use different port
docker run -p 8000:3000 titan-backend:1.0
```

### Can't connect to container

```bash
# Verify container is running
docker ps

# Check if port is mapped
docker port <container-name>

# Verify application is listening
docker exec <container-name> netstat -tlnp
```

### Image build fails

```bash
# Check Dockerfile syntax
docker build --progress=plain -t titan-backend:1.0 .

# View layer-by-layer what's happening
docker build --verbose -t titan-backend:1.0 .
```

---

## Next Steps

1. **Docker Compose**: Orchestrate multiple containers (database, frontend, backend)
2. **Container Registry**: Push images to Docker Hub or private registry
3. **Multi-stage Builds**: Optimize image size with build stages
4. **Health Checks**: Add HEALTHCHECK instruction
5. **Networking**: Connect containers on same network
6. **Volumes**: Persist data across container restarts

---

## Resources

- [Docker Official Documentation](https://docs.docker.com/)
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Node.js Docker Image](https://hub.docker.com/_/node)
- [Alpine Linux Documentation](https://alpinelinux.org/about/)

---

## Quick Reference

### Build and Run

```bash
# Build
docker build -t titan-backend:1.0 .

# Run (foreground)
docker run -p 3000:3000 titan-backend:1.0

# Run (background)
docker run -d -p 3000:3000 --name titan-api titan-backend:1.0

# Test
curl http://localhost:3000/health

# Logs
docker logs -f titan-api

# Stop
docker stop titan-api

# Remove
docker rm titan-api
```

### Image Management

```bash
docker images                          # List images
docker inspect titan-backend:1.0       # Image details
docker history titan-backend:1.0       # Show layers
docker tag titan-backend:1.0 my-app:v1 # Retag image
docker rmi titan-backend:1.0           # Delete image
```

### Container Management

```bash
docker ps                      # List running containers
docker ps -a                   # List all containers
docker inspect <container-id>  # Container details
docker exec -it <id> /bin/sh   # Open shell in container
docker attach <container-id>   # Attach to container logs
```

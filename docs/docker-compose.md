# Docker Compose for Titan

This document explains Docker Compose and the Titan multi-service setup.

## What is Docker Compose?

Docker Compose is a tool for defining and running multi-container Docker applications. It allows you to use a YAML file to configure application services and then start all containers with a single command.

### Problem It Solves

**Without Docker Compose**:
```bash
# Start PostgreSQL
docker run -d -p 5432:5432 \
  -e POSTGRES_PASSWORD=password \
  -v titan-db:/var/lib/postgresql/data \
  postgres:16-alpine

# Get PostgreSQL container IP
POSTGRES_IP=$(docker inspect <container-id> -f '{{.NetworkSettings.IPAddress}}')

# Start Backend (hardcode database IP)
docker run -d -p 3000:3000 \
  -e DATABASE_URL="postgresql://titan:password@$POSTGRES_IP:5432/titan" \
  titan-backend:1.0

# Multiple containers, manual IP management, error-prone
```

**With Docker Compose**:
```yaml
services:
  backend:
    build: ./app/backend
    ports: ["3000:3000"]
    environment:
      DATABASE_URL: postgresql://titan:password@postgres:5432/titan
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: password
    volumes: [titan-db:/var/lib/postgresql/data]
```

Then simply:
```bash
docker-compose up
```

---

## Core Concepts

### Services

A **service** is a container that Docker Compose manages.

Each service:
- Has its own container
- Can be built from Dockerfile or pulled from image
- Gets environment variables
- Connects to defined networks
- May mount volumes
- Has restart and health check policies

**Service discovery**: Services communicate by service name
```
Backend → postgres:5432
Docker resolves "postgres" to PostgreSQL container IP
```

### Networks

A **network** allows containers to communicate with each other.

**Default behavior**:
- Docker Compose creates a default network
- All services connect to it
- Services discover each other by name

**Custom networks** (recommended):
- More organized and explicit
- Can have multiple networks for isolation
- Services only see what they need

**Service discovery flow**:
```
1. Backend container tries: connect to postgres:5432
2. Docker DNS (127.0.0.11:53): "postgres" → 172.20.0.2
3. Routing: 172.20.0.2:5432 → PostgreSQL container
4. PostgreSQL: Connection established
```

### Volumes

A **volume** is persistent storage for container data.

**Why volumes matter**:
- Container files are temporary (lost when container removed)
- Volumes persist outside containers
- Database data must be in volumes
- Multiple containers can share volumes

**Volume types**:

| Type | Use Case | Lifecycle |
|------|----------|-----------|
| Named volumes | Database, persistent data | Managed by Docker |
| Bind mounts | Config files, code | Host filesystem |
| Anonymous volumes | Temporary storage | Removed with container |

**Volume lifecycle**:
```
docker-compose up      → Creates volume if needed
docker-compose down    → Keeps volume (data persists)
docker volume rm       → Manually delete volume (deletes data)
docker-compose down -v → Delete volumes with containers
```

**Important**: With our setup:
```bash
docker-compose down    # PostgreSQL container stops, volume keeps data
docker-compose up      # New container mounts existing volume, data restored
```

---

## Titan Architecture

### Service Overview

```
┌─────────────────────────────────────────────────────┐
│              Docker Compose                         │
│                                                     │
│  ┌──────────────────┐      ┌──────────────────┐    │
│  │  Backend         │      │  PostgreSQL      │    │
│  │  (Express)       │      │  (Database)      │    │
│  │  Port: 3000      │      │  Port: 5432      │    │
│  │  ──────────────  │      │  ──────────────  │    │
│  │  Connects to DB  │◄────►│  Stores Data     │    │
│  │  on: postgres    │      │  Volume: titan-db    │
│  │                  │      │                  │    │
│  └──────────────────┘      └──────────────────┘    │
│         │                         │                 │
│         └─────── titan-network ───┘                 │
│                                                     │
└─────────────────────────────────────────────────────┘
         │ Exposed                │ Not exposed
         v to host               v (internal only)
    localhost:3000         Only via backend
```

### Service Definitions

#### Backend Service

```yaml
backend:
  build: ./app/backend          # Build from Dockerfile
  container_name: titan-backend # Explicit name
  ports: ["3000:3000"]         # Map host:container port
  environment:                  # Configuration
    NODE_ENV: production
    DATABASE_URL: postgresql://...@postgres:5432/titan
  networks: [titan-network]     # Connect to custom network
  depends_on:                   # Wait for postgres
    postgres:
      condition: service_healthy
  healthcheck: ...              # Liveness check
```

**Key points**:
- Builds image from `app/backend/Dockerfile`
- Exposes port 3000 to host (localhost:3000)
- Connects to PostgreSQL via service name "postgres"
- Service discovery: "postgres" resolves to PostgreSQL container

#### PostgreSQL Service

```yaml
postgres:
  image: postgres:16-alpine     # Official image
  container_name: titan-postgres
  ports: ["5432:5432"]         # Map for external access
  environment:                  # Database configuration
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres_admin_password
    POSTGRES_DB: titan         # Create this database
  networks: [titan-network]     # Custom network
  volumes:                       # Persistent storage
    - titan-db:/var/lib/postgresql/data
  healthcheck: ...              # Database readiness check
```

**Key points**:
- Uses official PostgreSQL image (Alpine variant, ~80MB)
- Creates database "titan" on startup
- Stores data in named volume "titan-db"
- Health check ensures database is ready before backend starts

---

## Networks Explained

### Docker Network Basics

A Docker network connects containers so they can communicate.

**Network types**:

| Type | Scope | Use Case |
|------|-------|----------|
| bridge | Single host | Most common, default |
| host | Single host | High performance, less isolation |
| overlay | Multiple hosts | Docker Swarm, clustering |
| macvlan | Single host | Advanced, MAC address per container |

**Bridge network** (used in Titan):
- Default for docker-compose
- Isolated from host
- Services access by name
- Built-in DNS resolution

### Service Discovery

How containers find each other by name:

**DNS Resolution Flow**:
```
1. Backend container: "connect to postgres:5432"
2. Backend queries DNS: "What's postgres IP?"
3. Docker DNS (127.0.0.11:53): "postgres is 172.20.0.2"
4. Connection established to 172.20.0.2:5432
5. PostgreSQL receives connection
```

**Why not hardcoded IPs?**
- Container IPs are dynamic (change on restart)
- Service names are stable (never change)
- Docker DNS makes this automatic

**Service discovery vs Port Mapping**:
```
Port Mapping:
  localhost:3000 ──docker port mapper──> container port 3000
  Used for: External access from host

Service Discovery:
  postgres:5432 ──docker DNS──> container IP:5432
  Used for: Container-to-container communication
```

### Multiple Networks

Services can connect to multiple networks:

```yaml
networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge

services:
  backend:
    networks: [frontend-network, backend-network]
  
  postgres:
    networks: [backend-network]
  
  frontend:
    networks: [frontend-network]

# Result: backend connects to both frontend and postgres
#         frontend and postgres cannot communicate directly
```

---

## Volumes Explained

### What Happens Without Volumes

```
Container created with image
├─ Image layers (read-only)
└─ Container layer (writable, temporary)

When container is removed:
- Container layer is deleted
- All changes are lost
- Data is gone forever
```

For a database, this is catastrophic:
```
docker-compose down
→ PostgreSQL container stops
→ Container layer deleted
→ All database data lost
```

### What Happens With Volumes

```
Container created with image
├─ Image layers (read-only)
├─ Container layer (temporary)
└─ Volume mount (persistent)
   └─ /var/lib/postgresql/data → titan-db volume
      └─ Data persists on host

When container is removed:
- Container layer deleted (temporary)
- Volume remains (persistent)
- Data is safe
```

### Named Volumes

Named volumes are Docker-managed persistent storage.

**Creation**:
```yaml
volumes:
  titan-db:
    driver: local
```

When you run `docker-compose up`:
1. Docker checks if volume "titan-db" exists
2. If not, creates it
3. PostgreSQL container mounts volume
4. Data written to volume

**Storage location**:
```
Host: /var/lib/docker/volumes/titan-db/_data/
Inside container: /var/lib/postgresql/data/
They're the same location (mounted)
```

**Persistence**:
```bash
docker-compose up    # PostgreSQL starts, data in volume
docker-compose down  # Container stops, volume persists
docker-compose up    # New container mounts existing volume, data restored
```

### Volume Lifecycle

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect titan-db

# Backup volume
docker run --rm -v titan-db:/data -v $(pwd):/backup \
  alpine tar czf /backup/db.tar.gz /data

# Delete volume (CAREFUL - deletes data)
docker volume rm titan-db

# Delete in compose
docker-compose down -v  # Removes containers AND volumes
```

---

## Environment Variables

Environment variables configure application behavior.

### Setting Environment Variables

**In docker-compose.yml**:
```yaml
environment:
  NODE_ENV: production
  PORT: 3000
  DATABASE_URL: postgresql://user:pass@postgres:5432/titan
```

**In .env file**:
```bash
# .env file
NODE_ENV=production
PORT=3000
DATABASE_URL=postgresql://user:pass@postgres:5432/titan

# Add to .gitignore (don't commit!)
# docker-compose.yml:
# env_file: .env
```

**Command line override**:
```bash
docker-compose -e NODE_ENV=development up
```

### Variable Interpolation

Variables can reference other variables:

```yaml
environment:
  DB_USER: titan
  DB_PASS: secret123
  DB_HOST: postgres
  DB_PORT: 5432
  DB_NAME: titan
  DATABASE_URL: postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}
  # Resolves to: postgresql://titan:secret123@postgres:5432/titan
```

### Database Connection Variables

Backend needs to connect to PostgreSQL:

```javascript
// In Node.js
const dbUrl = process.env.DATABASE_URL;
// Or individual variables:
const host = process.env.DB_HOST;    // "postgres"
const port = process.env.DB_PORT;    // 5432
const user = process.env.DB_USER;    // "titan"
const password = process.env.DB_PASSWORD;
const database = process.env.DB_NAME; // "titan"
```

**Connection string format**:
```
postgresql://username:password@hostname:port/database
postgresql://titan:titan_pass@postgres:5432/titan
```

**Why service name works**:
- Host: "postgres" (service name)
- Docker DNS resolves to container IP
- Backend connects successfully

---

## Health Checks

Health checks determine if a container is ready and healthy.

### Why Health Checks Matter

**Without health checks**:
```
docker-compose up
1. PostgreSQL container starts
2. Backend starts immediately
3. Backend tries to connect to DB
4. Connection refused (DB still initializing)
5. Backend crashes
```

**With health checks**:
```
docker-compose up
1. PostgreSQL starts
2. Health check runs: "Is DB ready?"
3. Returns unhealthy (still initializing)
4. Backend waits (depends_on: condition: service_healthy)
5. Eventually DB becomes healthy
6. Backend starts, connects successfully
```

### Health Check Configuration

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s       # Check every 30 seconds
  timeout: 5s         # Wait max 5 seconds for response
  retries: 3          # Unhealthy after 3 failures
  start_period: 10s   # Don't check for first 10 seconds
```

**Parameters explained**:

| Parameter | Meaning | Example |
|-----------|---------|---------|
| `test` | Command to run | `curl http://localhost/health` |
| `interval` | Check frequency | Every 30 seconds |
| `timeout` | Max response time | 5 seconds |
| `retries` | Failures to mark unhealthy | 3 consecutive failures |
| `start_period` | Grace period | 10 seconds (for initialization) |

### Health Check Example: Backend

```yaml
backend:
  healthcheck:
    test: ["CMD", "curl", "-f", "-s", "http://localhost:3000/health"]
    interval: 30s
    timeout: 5s
    retries: 3
    start_period: 10s
```

Flow:
1. Container starts
2. Wait 10 seconds (start_period)
3. Every 30 seconds, curl `/health` endpoint
4. If returns 200-399: healthy
5. If returns 4xx/5xx: unhealthy, increment counter
6. After 3 consecutive failures: mark unhealthy
7. Orchestrator can take action (restart, replace)

### Health Check Example: PostgreSQL

```yaml
postgres:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 10s
```

Flow:
1. PostgreSQL starts (initialization can take 10-15 seconds)
2. Wait 10 seconds
3. Every 10 seconds, run `pg_isready`
4. If returns 0: ready, mark healthy
5. If returns non-zero: not ready, retry
6. After 5 consecutive failures: mark unhealthy

### Viewing Health Status

```bash
# Check container health
docker-compose ps
# Shows "healthy" or "unhealthy" status

# View detailed health info
docker inspect titan-backend | grep -A 10 '"Health"'

# View health check logs
docker-compose exec backend docker inspect self | grep -A 20 Health
```

---

## Common Workflows

### Start Services

**Development** (foreground, see logs):
```bash
docker-compose up
# Press Ctrl+C to stop
```

**Production** (background):
```bash
docker-compose up -d
docker-compose ps  # Verify status
docker-compose logs -f  # View logs
```

**Rebuild images**:
```bash
docker-compose up --build
docker-compose up --build -d
```

### Stop Services

**Stop temporarily** (can restart):
```bash
docker-compose stop
docker-compose start  # Restart
```

**Stop and remove** (containers gone, volumes persist):
```bash
docker-compose down
```

**Full cleanup** (containers AND volumes deleted):
```bash
docker-compose down -v
# WARNING: Database data is deleted!
```

### Monitoring

**View status**:
```bash
docker-compose ps
# Shows running containers, ports, health status
```

**View logs**:
```bash
docker-compose logs              # All services
docker-compose logs -f           # Follow (tail -f)
docker-compose logs backend      # Single service
docker-compose logs --tail 50    # Last 50 lines
```

**View service details**:
```bash
docker-compose config      # Show computed config
docker-compose images      # Show images used
docker-compose version     # Docker Compose version
```

### Database Management

**Connect to PostgreSQL**:
```bash
docker-compose exec postgres psql -U postgres

# Inside psql:
postgres=# \dt           # List tables
postgres=# \l            # List databases
postgres=# SELECT * FROM pg_user;  # List users
postgres=# \q            # Exit
```

**Run SQL command**:
```bash
docker-compose exec postgres psql -U postgres -c "SELECT version();"
```

**Create application user** (in addition to admin):
```bash
docker-compose exec postgres createuser -U postgres -P titan
# Prompts for password
```

**Backup database**:
```bash
docker-compose exec postgres pg_dump -U postgres titan > backup.sql
```

**Restore database**:
```bash
docker-compose exec -T postgres psql -U postgres titan < backup.sql
```

### Troubleshooting

**Container won't start**:
```bash
docker-compose logs <service>
# Shows error messages
```

**Services can't communicate**:
```bash
# Verify network
docker network ls
docker network inspect titan-network

# Test DNS resolution
docker-compose exec backend nslookup postgres
```

**Port already in use**:
```bash
# Check what's using the port
lsof -i :3000
lsof -i :5432

# Use different ports in compose file
# Change ports: ["8000:3000"]
```

**Health check failing**:
```bash
# View health status
docker-compose ps

# Check logs
docker-compose logs postgres
docker-compose logs backend

# Test health endpoint manually
docker-compose exec backend curl http://localhost:3000/health
docker-compose exec postgres pg_isready
```

---

## Security Considerations

### Current Setup (Development)

The `docker-compose.yml` is configured for local development:
- Passwords in plain text
- No encryption
- No authentication for services (internal only)
- Port 5432 exposed to host

### Production Improvements

**1. Use .env file** (not committed to git):
```bash
# .env
POSTGRES_PASSWORD=secure_random_password_123
# .gitignore: .env
```

**2. Use Docker Secrets** (Docker Swarm/Kubernetes):
```yaml
secrets:
  db_password:
    file: ./db_password.txt

services:
  postgres:
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

**3. Use external secrets management**:
```bash
# Vault, AWS Secrets Manager, etc.
docker-compose exec -e $(get-secrets) up
```

**4. Don't expose database port**:
```yaml
postgres:
  # Remove: ports: ["5432:5432"]
  # Only accessible from internal network
```

**5. Use strong passwords**:
```bash
# Generate secure password
openssl rand -base64 32
# Use in compose file or .env
```

---

## Next Steps

1. **Implement database initialization**: SQL scripts for schema setup
2. **Add volume backups**: Automated database backups
3. **Add caching**: Redis service for performance
4. **Add message queue**: RabbitMQ or similar
5. **Production deployment**: AWS ECS, Google Cloud Run, etc.
6. **Container orchestration**: Kubernetes for multi-container management

---

## Commands Reference

### Common Commands

```bash
# Start/stop
docker-compose up               # Start services
docker-compose up -d            # Start in background
docker-compose down             # Stop and remove
docker-compose restart          # Restart services

# View status
docker-compose ps               # List containers
docker-compose logs -f          # Follow logs
docker-compose config           # Show configuration

# Execute commands
docker-compose exec <service> <command>
docker-compose exec backend npm test
docker-compose exec postgres psql -U postgres

# Cleanup
docker-compose down -v          # Remove volumes (data deleted!)
docker system prune             # Remove unused resources
```

### Debugging Commands

```bash
# Check health
docker-compose ps
docker inspect <container-id> | grep -A 10 Health

# View network
docker network inspect titan-network

# Test connectivity
docker-compose exec backend ping postgres
docker-compose exec backend curl http://postgres:5432

# Check volumes
docker volume ls
docker volume inspect titan-db
```

---

## Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Compose File Reference](https://docs.docker.com/compose/compose-file/)
- [PostgreSQL Docker Image](https://hub.docker.com/_/postgres)
- [Docker Networking Guide](https://docs.docker.com/network/)
- [Docker Volumes Guide](https://docs.docker.com/storage/volumes/)


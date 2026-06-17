# Titan Backend Service

This document describes the Titan backend Express.js service, a lightweight HTTP API for the Titan local DevOps platform.

## Overview

The Titan Backend Service is a Node.js Express application that provides core API endpoints for the platform. It is designed to be:

- **Lightweight**: Minimal dependencies and fast startup
- **Local-first**: Runs entirely on WSL Ubuntu 26.04
- **Observable**: Includes health checks and status endpoints
- **Extensible**: Easy to add new endpoints and features

## Architecture

### Directory Structure

```
app/
└── backend/
    ├── package.json      # Project metadata and dependencies
    ├── server.js         # Main application entry point
    └── README.md         # Backend-specific documentation
```

### Technology Stack

- **Runtime**: Node.js 18.0.0+
- **Framework**: Express.js 4.18.2
- **Environment**: WSL Ubuntu 26.04
- **Port**: 3000 (default)

## Quick Start

### Prerequisites

Install Node.js and npm on your WSL Ubuntu system:

```bash
# Install Node.js (using NodeSource repository)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version    # Should show v18.x.x or higher
npm --version     # Should show 9.x.x or higher
```

### Installation

Navigate to the backend directory and install dependencies:

```bash
cd app/backend
npm install
```

### Running the Server

**Production mode**:

```bash
npm start
```

**Development mode** (with auto-reload):

```bash
npm run dev
```

### Verify Service

Once running, test the endpoints:

```bash
# Test root endpoint
curl http://localhost:3000/

# Test health check
curl http://localhost:3000/health

# Expected output:
# GET / returns: {"project":"Titan","status":"running",...}
# GET /health returns: {"status":"healthy",...}
```

## API Endpoints

### GET /

**Purpose**: Return service status and basic information

**Request**:
```
GET http://localhost:3000/
```

**Response** (HTTP 200 OK):
```json
{
  "project": "Titan",
  "status": "running",
  "environment": "development",
  "timestamp": "2026-06-17T14:30:00.000Z"
}
```

**Use Cases**:
- Verify service is running
- Get deployment information
- Integration with monitoring dashboards
- Status page displays

---

### GET /health

**Purpose**: Health check endpoint for monitoring and orchestration systems

**Request**:
```
GET http://localhost:3000/health
```

**Response** (HTTP 200 OK):
```json
{
  "status": "healthy",
  "uptime": 123.456,
  "timestamp": "2026-06-17T14:30:00.000Z"
}
```

**Use Cases**:
- Liveness probes (is the process running?)
- Readiness probes (is the service ready to accept requests?)
- Health check scripts
- Monitoring and alerting systems

**Uptime Field**:
- Represents process uptime in seconds
- Useful for detecting process restarts
- Can be used to track service stability

---

### Error Responses

The API provides consistent error responses for invalid requests.

**404 Not Found** (Invalid endpoint):
```json
{
  "error": "Not Found",
  "message": "Cannot GET /invalid-path",
  "status": 404,
  "timestamp": "2026-06-17T14:30:00.000Z"
}
```

**500 Internal Server Error** (Server error):
```json
{
  "error": "Internal Server Error",
  "message": "An unexpected error occurred",
  "status": 500,
  "timestamp": "2026-06-17T14:30:00.000Z"
}
```

## Configuration

### Environment Variables

Configure the service using environment variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `PORT` | 3000 | Server listening port |
| `HOST` | 0.0.0.0 | Server listening address |
| `NODE_ENV` | development | Environment name (development/production) |

### Setting Environment Variables

**Temporary** (current session):
```bash
export PORT=3000
export NODE_ENV=production
npm start
```

**Persistent** (add to ~/.bashrc or ~/.profile):
```bash
echo 'export NODE_ENV=production' >> ~/.bashrc
source ~/.bashrc
```

**Using .env file** (future enhancement):
```bash
# Create .env file
echo "PORT=3000" > .env
echo "NODE_ENV=production" >> .env

# Install dotenv package and use it in server.js
npm install dotenv
```

## Development

### Code Structure

**server.js** is organized into clear sections:

1. **Module Imports**: Required dependencies (Express)
2. **Configuration**: Environment and server settings
3. **Application Initialization**: Express app setup and middleware
4. **Route Handlers**: Endpoint definitions (GET /, GET /health)
5. **Error Handling**: 404 and global error handlers
6. **Server Startup**: Listen and log initialization
7. **Graceful Shutdown**: SIGTERM/SIGINT handling
8. **Process Error Handlers**: Uncaught exceptions and promise rejections

### Adding New Endpoints

To add a new endpoint, follow this pattern in `server.js`:

```javascript
/**
 * New endpoint - GET /api/status
 * 
 * Purpose: Describe the endpoint purpose
 * 
 * Returns:
 *   { ... response data ... }
 * 
 * HTTP Status: 200 OK
 */
app.get('/api/status', (req, res) => {
  // Implement endpoint logic
  const response = { /* ... */ };
  
  // Send response with appropriate status code
  res.status(200).json(response);
});
```

### Testing Endpoints

Use `curl` for simple testing:

```bash
# GET request
curl -X GET http://localhost:3000/

# GET with headers
curl -X GET -H "Content-Type: application/json" http://localhost:3000/

# POST request (if endpoint supports it)
curl -X POST -H "Content-Type: application/json" \
  -d '{"key":"value"}' \
  http://localhost:3000/api/endpoint

# Pretty print JSON response
curl -s http://localhost:3000/health | jq .
```

### Debugging

Enable detailed logging:

```bash
# Set debug environment variable
DEBUG=* npm start

# Or use Node.js inspector
node --inspect server.js
# Then open chrome://inspect in Chrome DevTools
```

## Deployment

### Local Development Deployment

1. Install dependencies:
   ```bash
   cd app/backend
   npm install
   ```

2. Start the server:
   ```bash
   npm start
   ```

3. Verify it's running:
   ```bash
   curl http://localhost:3000/health
   ```

### Process Management (with PM2)

For long-running local deployments, use PM2:

```bash
# Install PM2 globally
npm install -g pm2

# Start service with PM2
pm2 start server.js --name "titan-backend"

# View logs
pm2 logs titan-backend

# Stop service
pm2 stop titan-backend

# Restart on system reboot
pm2 startup
pm2 save
```

### Monitoring

Create a monitoring script in `scripts/monitor-backend.sh`:

```bash
#!/bin/bash

# Check if backend is running
if curl -s http://localhost:3000/health | grep -q "healthy"; then
    echo "✓ Backend is healthy"
else
    echo "✗ Backend health check failed"
    exit 1
fi
```

## Best Practices

### 1. Error Handling

The service includes comprehensive error handling:

- Try-catch blocks for async operations
- Global error middleware for unhandled errors
- Graceful shutdown on signals
- Uncaught exception handlers

### 2. Logging

The service logs important events:

```javascript
// Request logging
console.log(`[${timestamp}] ${req.method} ${req.path}`);

// Error logging
console.error('Error:', err);

// Server startup
console.log(`Server started: ${new Date().toISOString()}`);
```

### 3. Health Checks

The `/health` endpoint provides:

- Service status
- Process uptime
- Timestamp for monitoring systems

### 4. Security Considerations

**Current Implementation**:
- No authentication (local-only)
- No rate limiting (local-only)
- No CORS configuration needed (local development)

**For Production-like Scenarios**:

```javascript
// Install packages
npm install cors helmet express-rate-limit

// In server.js
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

app.use(helmet());  // Security headers

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 100  // limit each IP to 100 requests per windowMs
});
app.use(limiter);
```

## Integration with Titan

The backend service integrates with the Titan platform as follows:

### Phase 2: Environment Foundation
- ✓ Backend service setup
- Health check integration with Linux scripts

### Phase 3: Tool Integration
- API endpoints for configuration management
- Endpoints for service orchestration

### Phase 4: Sample Deployment
- Deploy and validate backend service
- Test health checks with monitoring scripts

### Phase 5: Observability
- Integrate with logging system
- Add metrics endpoints

## Troubleshooting

### Port Already in Use

If port 3000 is already in use:

```bash
# Find process using port 3000
lsof -i :3000

# Kill the process (replace PID)
kill -9 <PID>

# Or use different port
PORT=3001 npm start
```

### Module Not Found

If you get "Cannot find module 'express'":

```bash
# Reinstall dependencies
npm install

# Clear npm cache
npm cache clean --force
npm install
```

### Connection Refused

If you can't connect to localhost:3000:

```bash
# Verify server is running
ps aux | grep node

# Check if port is listening
netstat -tlnp | grep 3000

# Try connecting
curl http://localhost:3000/
```

### Node Version Issues

Ensure you have Node.js 18.0.0 or higher:

```bash
node --version

# If older version, update Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
```

## Next Steps

1. **Add Authentication**: Implement JWT or API key authentication
2. **Add Database**: Connect to PostgreSQL or MongoDB
3. **Add Metrics**: Implement Prometheus metrics endpoint
4. **Add Logging**: Integrate with structured logging system
5. **Add Testing**: Create unit and integration tests
6. **Docker Support**: Create Dockerfile and docker-compose.yml

## Resources

- [Express.js Documentation](https://expressjs.com/)
- [Node.js Best Practices](https://nodejs.org/en/docs/guides/)
- [REST API Design Guidelines](https://restfulapi.net/)
- [HTTP Status Codes](https://httpwg.org/specs/rfc7231.html#status.codes)

## Support

For issues or questions:

1. Check the troubleshooting section above
2. Review server logs: `npm start 2>&1 | tee server.log`
3. Test endpoints with curl
4. Verify dependencies are installed: `npm list`

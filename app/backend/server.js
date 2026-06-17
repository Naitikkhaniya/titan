////////////////////////////////////////////////////////////////////////////////
// Titan Backend Service
//
// Purpose: Express.js backend service for Titan local DevOps platform
// Port: 3000
// Environment: WSL Ubuntu 26.04
//
// This service provides core API endpoints for the Titan platform,
// including health checks and service status.
//
// Author: Titan DevOps Platform
// Last Modified: 2026-06-17
////////////////////////////////////////////////////////////////////////////////

// ============================================================================
// Module Imports
// ============================================================================

// Import Express framework for building HTTP server
import express from 'express';

// ============================================================================
// Configuration
// ============================================================================

// Define the port the server will listen on
// Default to 3000, but allow override via environment variable
const PORT = process.env.PORT || 3000;

// Define the host to bind to
// 0.0.0.0 allows connections from any network interface
const HOST = process.env.HOST || '0.0.0.0';

// Get environment name (development, production, etc.)
const NODE_ENV = process.env.NODE_ENV || 'development';

// ============================================================================
// Application Initialization
// ============================================================================

// Create Express application instance
const app = express();

// Middleware: Parse JSON request bodies
// This allows the server to handle JSON payloads in request bodies
app.use(express.json());

// Middleware: Request logging
// Log all incoming requests with method, path, and timestamp
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.path}`);
  next();
});

// ============================================================================
// Route Handlers
// ============================================================================

/**
 * Root endpoint - GET /
 * 
 * Purpose: Provide basic service information
 * 
 * Returns:
 *   {
 *     "project": "Titan",
 *     "status": "running",
 *     "environment": "development",
 *     "timestamp": "2026-06-17T14:30:00.000Z"
 *   }
 * 
 * HTTP Status: 200 OK
 */
app.get('/', (req, res) => {
  // Create response object with service information
  const response = {
    project: 'Titan',
    status: 'running',
    environment: NODE_ENV,
    timestamp: new Date().toISOString()
  };

  // Send response with HTTP 200 status code
  res.status(200).json(response);
});

/**
 * Health Check endpoint - GET /health
 * 
 * Purpose: Provide liveness and readiness probe for monitoring/orchestration
 * 
 * Returns:
 *   {
 *     "status": "healthy",
 *     "uptime": 123.456,
 *     "timestamp": "2026-06-17T14:30:00.000Z"
 *   }
 * 
 * HTTP Status: 200 OK
 * 
 * Notes:
 *   - This endpoint is used by health check scripts and monitoring systems
 *   - Returns basic server metrics (uptime in seconds)
 *   - Should be lightweight and fast
 */
app.get('/health', (req, res) => {
  // Create health check response
  const response = {
    status: 'healthy',
    uptime: process.uptime(),  // Process uptime in seconds since start
    timestamp: new Date().toISOString()
  };

  // Send response with HTTP 200 status code
  res.status(200).json(response);
});

// ============================================================================
// Error Handling Middleware
// ============================================================================

/**
 * 404 Not Found Handler
 * 
 * Purpose: Handle requests to undefined routes
 * 
 * Triggered when no route matches the request path
 */
app.use((req, res) => {
  // Create error response
  const errorResponse = {
    error: 'Not Found',
    message: `Cannot ${req.method} ${req.path}`,
    status: 404,
    timestamp: new Date().toISOString()
  };

  // Send 404 response
  res.status(404).json(errorResponse);
});

/**
 * Global Error Handler
 * 
 * Purpose: Handle unexpected errors and provide consistent error responses
 * 
 * Parameters:
 *   - err: Error object
 *   - req: Express request object
 *   - res: Express response object
 *   - next: Express next function
 */
app.use((err, req, res, next) => {
  // Log error to console for debugging
  console.error('Error:', err);

  // Create error response
  const errorResponse = {
    error: err.name || 'Internal Server Error',
    message: err.message || 'An unexpected error occurred',
    status: err.status || 500,
    timestamp: new Date().toISOString()
  };

  // Determine HTTP status code
  const statusCode = err.status || 500;

  // Send error response
  res.status(statusCode).json(errorResponse);
});

// ============================================================================
// Server Startup
// ============================================================================

/**
 * Start the Express server
 * 
 * This creates an HTTP server and begins listening for incoming connections
 * on the specified HOST and PORT.
 */
const server = app.listen(PORT, HOST, () => {
  // Log startup information to console
  console.log('');
  console.log('=====================================');
  console.log('Titan Backend Service');
  console.log('=====================================');
  console.log(`Server started: ${new Date().toISOString()}`);
  console.log(`Host:           ${HOST}`);
  console.log(`Port:           ${PORT}`);
  console.log(`Environment:    ${NODE_ENV}`);
  console.log('');
  console.log('Available endpoints:');
  console.log(`  GET http://localhost:${PORT}/       - Service status`);
  console.log(`  GET http://localhost:${PORT}/health - Health check`);
  console.log('');
  console.log('Press Ctrl+C to stop the server');
  console.log('=====================================');
  console.log('');
});

// ============================================================================
// Graceful Shutdown
// ============================================================================

/**
 * Handle graceful shutdown
 * 
 * Purpose: Cleanly close the server when receiving shutdown signals
 * 
 * Signals handled:
 *   - SIGTERM: Termination signal
 *   - SIGINT: Interrupt signal (Ctrl+C)
 */
process.on('SIGTERM', () => {
  console.log('SIGTERM signal received: closing HTTP server');
  
  // Close the server
  server.close(() => {
    console.log('HTTP server closed');
    // Exit the process with success code
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('');
  console.log('SIGINT signal received: closing HTTP server');
  
  // Close the server
  server.close(() => {
    console.log('HTTP server closed');
    // Exit the process with success code
    process.exit(0);
  });
});

/**
 * Handle uncaught exceptions
 * 
 * Purpose: Log and handle any unhandled errors
 * 
 * Note: After logging, the process exits to ensure clean state
 */
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err);
  // Exit the process with error code
  process.exit(1);
});

/**
 * Handle unhandled promise rejections
 * 
 * Purpose: Log and handle any unhandled promise rejections
 */
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Exit the process with error code
  process.exit(1);
});

// Export app for testing purposes (optional)
export default app;

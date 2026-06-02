const express = require('express');
const path = require('path');
const app = express();

const PORT = process.env.PORT || 3000;
const WEB_DIR = path.join(__dirname, 'build', 'web');

// Request logger middleware
app.use((req, res, next) => {
  const timestamp = new Date().toISOString();
  console.log(`[${timestamp}] ${req.method} ${req.url}`);
  next();
});

// Serve static files from build/web directory
app.use(express.static(WEB_DIR));

// Fallback to index.html for Single Page Application routing (SPA routing)
// If the path doesn't point to a file (doesn't contain a dot in the last path segment),
// we fall back to index.html so Flutter Web can handle the route.
app.get('*', (req, res) => {
  // Check if request is likely looking for a static asset that doesn't exist
  const hasExtension = path.extname(req.path) !== '';
  if (hasExtension) {
    console.warn(`[404] Asset not found: ${req.path}`);
    return res.status(404).send('Asset not found');
  }
  
  res.sendFile(path.join(WEB_DIR, 'index.html'));
});

// Start listening
app.listen(PORT, '0.0.0.0', () => {
  console.log('=============================================');
  console.log(` MS Dashboard Server started successfully!`);
  console.log(` Mode: Production`);
  console.log(` Port: ${PORT}`);
  console.log(` Serving from: ${WEB_DIR}`);
  console.log(` Access URL: http://localhost:${PORT}`);
  console.log('=============================================');
});

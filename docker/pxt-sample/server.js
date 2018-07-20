'use strict';

const express = require('express');
var os = require('os');
var HOSTNAME = os.hostname();

// Constants
const PORT = 8080;
const HOST = '0.0.0.0';

// App
const app = express();
app.get('/', (req, res) => {
  res.send(`Node.js running on ${PORT} on container ${HOSTNAME}\n`);
});

app.listen(PORT, HOST);
console.log(`Running on http://${HOST}:${PORT}`);


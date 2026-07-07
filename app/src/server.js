const express = require("express");
const config = require("./config");

const app = express();

app.get("/", (req, res) => {
  res.json({
    service: config.serviceName,
    message: "Production Support Lab API",
    status: "running",
    environment: config.appEnv,
    version: config.appVersion
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: config.serviceName,
    environment: config.appEnv,
    version: config.appVersion,
    uptimeSeconds: Math.round(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

app.get("/error", (req, res) => {
  throw new Error("Intentional test error for troubleshooting practice");
});

app.use((err, req, res, next) => {
  console.error(`[ERROR] ${new Date().toISOString()} - ${err.message}`);

  res.status(500).json({
    status: "error",
    message: "Internal server error"
  });
});

app.listen(config.port, () => {
  console.log(`[INFO] ${config.serviceName} listening on port ${config.port} in ${config.appEnv} mode`);
});

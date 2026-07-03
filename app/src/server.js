const express = require("express");

const app = express();

const PORT = process.env.PORT || 3000;
const SERVICE_NAME = process.env.SERVICE_NAME || "linux-production-support-lab";

app.get("/", (req, res) => {
  res.json({
    service: SERVICE_NAME,
    message: "Production Support Lab API",
    status: "running"
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: SERVICE_NAME,
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

app.listen(PORT, () => {
  console.log(`[INFO] ${SERVICE_NAME} listening on port ${PORT}`);
});

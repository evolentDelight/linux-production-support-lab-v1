const rawPort = process.env.PORT || "3000";
const port = Number.parseInt(rawPort, 10);

if (Number.isNaN(port) || port <=0 || port > 65535){
  throw new Error(`Invalid PORT value: ${rawPort}`);
}

const config = {
  port,
  serviceName: process.env.SERVICE_NAME || "linux-production-support-lab-v1",
  appEnv: process.env.APP_ENV || "development",
  appVersion: process.env.APP_VERSION || "v1.0.0",
  logLevel: process.env.LOG_LEVEL || "info",
  databaseUrl: process.env.DATABASE_URL || ""
}

module.exports = config;
const fs = require('fs');
const path = require('path');
const config = require('./config');

const appLogPath = path.join(config.logDir, 'app.log');
const errorLogPath = path.join(config.logDir, 'error.log');

function ensureLogDirectory(){
  try {
    fs.mkdirSync(config.logDir, { recursive : true });
  } catch(err){
    console.error(`[LOGGER_ERROR] Failed to create log directory: ${err.message}`)
  }
}

function writeJsonLine(filePath, entry){
  const line = `${JSON.stringify(entry)}\n`;

  try{
    fs.appendFileSync(filePath, line);
  } catch(err){
    console.error(`[LOGGER_ERROR] Failed to create log directory: ${err.message}`)
  }
}

function log(level, message, metadata = {}){
  ensureLogDirectory();

  const entry = {
    timestamp: new Date().toISOString(),
    level,
    service: config.serviceName,
    environment: config.appEnv,
    version: config.appVersion,
    message,
    ...metadata
  }

  writeJsonLine(appLogPath, entry);

  if(level === "error"){
    writeJsonLine(errorLogPath, entry);
    console.error(JSON.stringify(entry));
  } else{
    console.log(JSON.stringify(entry));
  }
}

function info(message, metadata = {}){
  log('info', message, metadata);
}

function warn(message, metadata = {}){
  log('warn', message, metadata);
}

function error(message, metadata = {}){
  log('error', message, metadata);
}

module.exports = {
  info,
  warn,
  error
}
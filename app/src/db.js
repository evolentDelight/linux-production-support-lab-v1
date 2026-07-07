const { Pool } = require("pg");
const config = require('./config');

if(!config.databaseUrl){
  console.warn('[WARN] DATABASE_URL is not configured. Database endpoints will fail.');
}

const pool = new Pool({
  connectionString: config.databaseUrl
});

async function query(text, params){
  if(!config.databaseUrl){
    throw new Error('DATABASE_URL is not configured.')
  }

  return pool.query(text, params);
}

async function checkDatabase(){
  const result = await query(
    'SELECT NOW() AS current_time, current_database() AS database_name'
  );

  return result.rows[0];
}

module.exports = {
  query,
  checkDatabase
};
#!/usr/bin/env node

/**
 * Database Migration Runner
 *
 * Usage:
 *   node database/run_migration.js          # Run all pending migrations
 *   node database/run_migration.js seed     # Run seed data
 *   node database/run_migration.js status   # Show migration status
 *   node database/run_migration.js reset    # Reset database (DROP + migrate + seed)
 */

const mysql = require('mysql2/promise');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../server/.env') });

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');
const SEEDS_DIR = path.join(__dirname, 'seeds');

async function createConnection(withDatabase = true) {
  const config = {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER || 'root',
    password: process.env.DB_PASSWORD || '',
    multipleStatements: true,
    charset: 'utf8mb4',
  };
  if (withDatabase) {
    config.database = process.env.DB_NAME || 'elder_smart_helper';
  }
  return mysql.createConnection(config);
}

async function ensureMigrationsTable(conn) {
  await conn.query(`
    CREATE TABLE IF NOT EXISTS migrations (
      id INT PRIMARY KEY AUTO_INCREMENT,
      version VARCHAR(20) NOT NULL UNIQUE,
      description VARCHAR(255) NOT NULL,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  `);
}

async function getAppliedMigrations(conn) {
  const [rows] = await conn.query('SELECT version FROM migrations ORDER BY version');
  return new Set(rows.map(r => r.version));
}

function getMigrationFiles() {
  return fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();
}

function getSeedFiles() {
  if (!fs.existsSync(SEEDS_DIR)) return [];
  return fs.readdirSync(SEEDS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();
}

async function runMigrations() {
  const conn = await createConnection();
  try {
    await ensureMigrationsTable(conn);
    const applied = await getAppliedMigrations(conn);
    const files = getMigrationFiles();

    let count = 0;
    for (const file of files) {
      const version = file.split('_')[0];
      if (applied.has(version)) {
        console.log(`  ✓ ${file} (already applied)`);
        continue;
      }

      const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
      console.log(`  ▶ Applying ${file}...`);
      await conn.query(sql);
      console.log(`  ✓ ${file} applied`);
      count++;
    }

    if (count === 0) {
      console.log('  No pending migrations.');
    } else {
      console.log(`\n  Applied ${count} migration(s).`);
    }
  } finally {
    await conn.end();
  }
}

async function runSeeds() {
  const conn = await createConnection();
  try {
    const files = getSeedFiles();
    if (files.length === 0) {
      console.log('  No seed files found.');
      return;
    }

    for (const file of files) {
      const sql = fs.readFileSync(path.join(SEEDS_DIR, file), 'utf8');
      console.log(`  ▶ Seeding ${file}...`);
      await conn.query(sql);
      console.log(`  ✓ ${file} seeded`);
    }
    console.log('\n  Seed data loaded successfully.');
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      console.log('  ⚠ Seed data already exists (duplicate entries skipped).');
    } else {
      throw err;
    }
  } finally {
    await conn.end();
  }
}

async function showStatus() {
  const conn = await createConnection();
  try {
    await ensureMigrationsTable(conn);
    const applied = await getAppliedMigrations(conn);
    const files = getMigrationFiles();

    console.log('\n  Migration Status:');
    console.log('  ─────────────────────────────────────');
    for (const file of files) {
      const version = file.split('_')[0];
      const status = applied.has(version) ? '✅ Applied' : '⏳ Pending';
      console.log(`  ${status}  ${file}`);
    }
    console.log('');
  } finally {
    await conn.end();
  }
}

async function resetDatabase() {
  const dbName = process.env.DB_NAME || 'elder_smart_helper';
  console.log(`\n  ⚠️  This will DROP and recreate database "${dbName}"!`);
  console.log('  Press Ctrl+C within 3 seconds to cancel...\n');
  await new Promise(r => setTimeout(r, 3000));

  const conn = await createConnection(false);
  try {
    console.log(`  ▶ Dropping database ${dbName}...`);
    await conn.query(`DROP DATABASE IF EXISTS ${dbName}`);
    console.log(`  ✓ Database dropped`);

    console.log(`  ▶ Running migrations...`);
    await conn.end();
    await runMigrations();

    console.log(`  ▶ Running seeds...`);
    await runSeeds();

    console.log('\n  ✅ Database reset complete!\n');
  } catch (err) {
    await conn.end();
    throw err;
  }
}

// CLI
const command = process.argv[2] || 'migrate';

(async () => {
  console.log('\n  ElderSmartHelper Database Migration Tool\n');
  try {
    switch (command) {
      case 'migrate':
        console.log('  Running migrations...\n');
        await runMigrations();
        break;
      case 'seed':
        console.log('  Running seeds...\n');
        await runSeeds();
        break;
      case 'status':
        await showStatus();
        break;
      case 'reset':
        await resetDatabase();
        break;
      default:
        console.log('  Usage:');
        console.log('    node run_migration.js          # Run migrations');
        console.log('    node run_migration.js seed     # Run seeds');
        console.log('    node run_migration.js status   # Show status');
        console.log('    node run_migration.js reset    # Reset database');
    }
  } catch (err) {
    console.error('\n  ❌ Error:', err.message);
    process.exit(1);
  }
})();

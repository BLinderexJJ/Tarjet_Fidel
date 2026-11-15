#!/usr/bin/env node
/**
 * Configura una instalación de Tarjet Fidel para un negocio concreto.
 *
 * Escribe `firebase.web.json` (credenciales de la app web), `.firebaserc`
 * (proyecto por defecto de la CLI) y ajusta `firestore.database` en
 * `firebase.json`. No sube nada a GitHub: esos archivos están ignorados.
 *
 * Uso interactivo:
 *   node tool/configure_firebase.mjs
 *
 * Uso con argumentos (útil para scripts):
 *   node tool/configure_firebase.mjs \
 *     --project=mi-negocio \
 *     --api-key=AIza... \
 *     --app-id=1:123:web:abc \
 *     --sender-id=123 \
 *     --auth-domain=mi-negocio.firebaseapp.com \
 *     --storage-bucket=mi-negocio.firebasestorage.app \
 *     --database=default
 *
 * Los valores de la app web están en Firebase Console →
 * Configuración del proyecto → Tus apps → App web.
 */

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { createInterface } from 'node:readline/promises';
import { stdin as input, stdout as output, argv, exit } from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const webConfigPath = path.join(root, 'firebase.web.json');
const firebaseRcPath = path.join(root, '.firebaserc');
const firebaseJsonPath = path.join(root, 'firebase.json');

const args = parseArgs(argv.slice(2));

function parseArgs(rawArgs) {
  const parsed = {};
  for (const raw of rawArgs) {
    if (!raw.startsWith('--')) continue;
    const [key, ...rest] = raw.slice(2).split('=');
    parsed[key] = rest.length > 0 ? rest.join('=') : 'true';
  }
  return parsed;
}

function readJson(filePath) {
  if (!existsSync(filePath)) return null;
  try {
    return JSON.parse(readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

const existingWeb = readJson(webConfigPath) ?? {};
const isReal = (value) => typeof value === 'string' && value.trim() && value !== 'REPLACE_ME';

const rl = input.isTTY
  ? createInterface({ input, output })
  : null;

async function ask(label, currentValue, fallback) {
  const suggested = isReal(currentValue)
    ? currentValue
    : isReal(fallback)
      ? fallback
      : '';
  if (!rl) {
    if (suggested) return suggested;
    throw new Error(`Falta --${label} y no hay terminal interactiva.`);
  }
  const suffix = suggested ? ` [${suggested}]` : '';
  const answer = (await rl.question(`${label}${suffix}: `)).trim();
  return answer || suggested;
}

function print(message) {
  output.write(`${message}\n`);
}

try {
  print('');
  print('Configuración de Tarjet Fidel para un negocio');
  print('--------------------------------------------');
  print('Puedes obtener estos datos en Firebase Console → Configuración del proyecto → Tus apps → App web.');
  print('');

  const projectId = await ask(
    'ID del proyecto Firebase (--project)',
    args.project ?? existingWeb.FIREBASE_PROJECT_ID,
  );
  if (!projectId) throw new Error('El ID del proyecto es obligatorio.');

  const apiKey = await ask(
    'API key (--api-key)',
    args['api-key'] ?? existingWeb.FIREBASE_API_KEY,
  );
  if (!apiKey) throw new Error('La API key es obligatoria.');

  const appId = await ask(
    'App ID web (--app-id)',
    args['app-id'] ?? existingWeb.FIREBASE_APP_ID,
  );
  if (!appId) throw new Error('El App ID es obligatorio.');

  const senderId = await ask(
    'Messaging sender ID (--sender-id)',
    args['sender-id'] ?? existingWeb.FIREBASE_MESSAGING_SENDER_ID,
  );
  if (!senderId) throw new Error('El Messaging sender ID es obligatorio.');

  const authDomain = await ask(
    'Auth domain (--auth-domain)',
    args['auth-domain'] ?? existingWeb.FIREBASE_AUTH_DOMAIN,
    `${projectId}.firebaseapp.com`,
  );

  const storageBucket = await ask(
    'Storage bucket (--storage-bucket)',
    args['storage-bucket'] ?? existingWeb.FIREBASE_STORAGE_BUCKET,
    `${projectId}.firebasestorage.app`,
  );

  const measurementId = await ask(
    'Measurement ID (--measurement-id, opcional)',
    args['measurement-id'] ?? existingWeb.FIREBASE_MEASUREMENT_ID,
  );

  const databaseId = await ask(
    'ID de la base Firestore (--database)',
    args.database ?? existingWeb.FIRESTORE_DATABASE_ID,
    'default',
  );

  const webConfig = {
    FIREBASE_API_KEY: apiKey,
    FIREBASE_APP_ID: appId,
    FIREBASE_MESSAGING_SENDER_ID: senderId,
    FIREBASE_PROJECT_ID: projectId,
    FIREBASE_AUTH_DOMAIN: authDomain,
    FIREBASE_STORAGE_BUCKET: storageBucket,
    FIREBASE_MEASUREMENT_ID: measurementId ?? '',
    FIRESTORE_DATABASE_ID: databaseId || 'default',
  };

  writeFileSync(webConfigPath, `${JSON.stringify(webConfig, null, 2)}\n`);
  writeFileSync(
    firebaseRcPath,
    `${JSON.stringify({ projects: { default: projectId } }, null, 2)}\n`,
  );

  const firebaseJson = readJson(firebaseJsonPath);
  if (firebaseJson) {
    firebaseJson.firestore = {
      ...(firebaseJson.firestore ?? {}),
      database: webConfig.FIRESTORE_DATABASE_ID,
    };
    writeFileSync(firebaseJsonPath, `${JSON.stringify(firebaseJson, null, 2)}\n`);
  }

  print('');
  print('Listo. Archivos actualizados:');
  print(`  - ${path.relative(root, webConfigPath)}`);
  print(`  - ${path.relative(root, firebaseRcPath)}`);
  if (firebaseJson) print(`  - ${path.relative(root, firebaseJsonPath)} (firestore.database)`);
  print('');
  print('Siguientes pasos:');
  print('  1. firebase login');
  print(`  2. firebase deploy --only firestore:rules,firestore:indexes --project ${projectId}`);
  print(`  3. flutter build web --release --no-wasm-dry-run --dart-define-from-file=firebase.web.json`);
  print(`  4. firebase deploy --only hosting --project ${projectId}`);
  print('');
  print('No subas firebase.web.json ni .firebaserc a GitHub: ya están en .gitignore.');
} catch (error) {
  print('');
  print(`Error: ${error instanceof Error ? error.message : error}`);
  print('Ejecuta `node tool/configure_firebase.mjs` sin argumentos para el modo interactivo.');
  exit(1);
} finally {
  rl?.close();
}

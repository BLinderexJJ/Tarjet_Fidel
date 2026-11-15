#!/usr/bin/env node
/**
 * Crea (o actualiza) la cuenta del administrador y siembra `config/main`.
 *
 * Requiere credenciales de administrador de Firebase:
 *   - GOOGLE_APPLICATION_CREDENTIALS apuntando a un service account JSON, o
 *   - `gcloud auth application-default login`, o
 *   - `--service-account ruta/al/service-account.json`.
 *
 * Ejemplo:
 *   npm run create-admin -- \
 *     --email admin@minegocio.com \
 *     --password "UnaClaveSegura123" \
 *     --name "Administrador" \
 *     --project mi-proyecto-firebase \
 *     --business "Mi Negocio"
 */
import { readFileSync } from 'node:fs';
import { randomInt } from 'node:crypto';

import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const DEFAULT_STAMPS_GOAL = 10;
const DEFAULT_MAX_USERS = 50;
const DEFAULT_THEME_COLOR = '#4F46E5';
const DEFAULT_REWARD = 'Completa tu tarjeta y llévate un premio.';

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;

    const withoutPrefix = token.slice(2);
    const equalsIndex = withoutPrefix.indexOf('=');
    if (equalsIndex >= 0) {
      args[withoutPrefix.slice(0, equalsIndex)] = withoutPrefix.slice(
        equalsIndex + 1,
      );
      continue;
    }

    const next = argv[index + 1];
    if (next && !next.startsWith('--')) {
      args[withoutPrefix] = next;
      index += 1;
    } else {
      args[withoutPrefix] = true;
    }
  }
  return args;
}

function fail(message) {
  console.error(`\n✖ ${message}\n`);
  process.exit(1);
}

function requireString(value, name) {
  if (typeof value !== 'string' || !value.trim()) {
    fail(`Falta el parámetro obligatorio --${name}.`);
  }
  return value.trim();
}

function positiveInt(value, fallback) {
  if (typeof value !== 'string' && typeof value !== 'number') return fallback;
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed < 1) return fallback;
  return Math.floor(parsed);
}

function generateCheckinCode(length = 6) {
  let code = '';
  for (let index = 0; index < length; index += 1) {
    code += ALPHABET[randomInt(0, ALPHABET.length)];
  }
  return code;
}

function buildCredential(serviceAccountPath) {
  if (serviceAccountPath) {
    let parsed;
    try {
      parsed = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
    } catch (error) {
      fail(`No se pudo leer el service account: ${error.message}`);
    }
    return cert(parsed);
  }
  return applicationDefault();
}

function printHelp() {
  console.log(`
Uso:
  npm run create-admin -- --email <correo> --password <clave> [opciones]

Obligatorios:
  --email <correo>            Correo real del administrador.
  --password <clave>          Contraseña del administrador (mínimo 6 caracteres).

Opciones:
  --name <nombre>             Nombre visible (por defecto "Administrador").
  --project <id>              ID del proyecto Firebase.
  --service-account <ruta>    JSON del service account.
  --business <nombre>         Nombre del negocio para config/main.
  --stamps-goal <n>           Sellos para el premio (por defecto ${DEFAULT_STAMPS_GOAL}).
  --max-users <n>             Límite de clientes (por defecto ${DEFAULT_MAX_USERS}).
  --reward <texto>            Descripción del premio.
  --contact <texto>           Datos de contacto mostrados al expirar la prueba.
  --theme <#RRGGBB>           Color del tema (por defecto ${DEFAULT_THEME_COLOR}).
  --trial-expiry <ISO 8601>   Fecha de expiración (espejo en config/main).
  --help                      Muestra esta ayuda.
`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));

  if (args.help) {
    printHelp();
    return;
  }

  const email = requireString(args.email, 'email');
  const password = requireString(args.password, 'password');
  const displayName =
    typeof args.name === 'string' && args.name.trim()
      ? args.name.trim()
      : 'Administrador';

  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    fail('El correo del administrador no es válido.');
  }
  if (password.length < 6) {
    fail('La contraseña debe tener al menos 6 caracteres.');
  }

  const projectId =
    (typeof args.project === 'string' && args.project.trim()) ||
    process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.FIREBASE_PROJECT ||
    undefined;

  const serviceAccountPath =
    (typeof args['service-account'] === 'string' &&
      args['service-account'].trim()) ||
    process.env.SERVICE_ACCOUNT_PATH ||
    undefined;

  if (!getApps().length) {
    initializeApp({
      credential: buildCredential(serviceAccountPath),
      ...(projectId ? { projectId } : {}),
    });
  }

  const auth = getAuth();
  const db = getFirestore();

  let user;
  let created = false;

  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({
      email,
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
    created = true;
  }

  if (!created) {
    await auth.updateUser(user.uid, {
      password,
      displayName,
      emailVerified: true,
      disabled: false,
    });
  }

  await auth.setCustomUserClaims(user.uid, { admin: true, role: 'admin' });

  const adminRef = db.doc(`admins/${user.uid}`);
  const adminSnapshot = await adminRef.get();
  const adminData = {
    email,
    displayName,
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (!adminSnapshot.exists) {
    adminData.createdAt = FieldValue.serverTimestamp();
  }
  await adminRef.set(adminData, { merge: true });

  const businessName =
    typeof args.business === 'string' && args.business.trim()
      ? args.business.trim()
      : 'Mi Negocio';
  const stampsGoal = positiveInt(args['stamps-goal'], DEFAULT_STAMPS_GOAL);
  const maxUsers = positiveInt(args['max-users'], DEFAULT_MAX_USERS);
  const themeColor =
    typeof args.theme === 'string' && /^#[0-9a-fA-F]{6}$/.test(args.theme)
      ? args.theme.toUpperCase()
      : DEFAULT_THEME_COLOR;
  const trialExpiry =
    typeof args['trial-expiry'] === 'string' && args['trial-expiry'].trim()
      ? args['trial-expiry'].trim()
      : null;

  const defaults = {
    businessName,
    logoUrl: '',
    stampsGoal,
    rewardDescription:
      typeof args.reward === 'string' && args.reward.trim()
        ? args.reward.trim()
        : DEFAULT_REWARD,
    themeColor,
    maxUsers,
    checkinCode: generateCheckinCode(),
    contactInfo:
      typeof args.contact === 'string' && args.contact.trim()
        ? args.contact.trim()
        : '',
    trialExpiryDate: trialExpiry,
  };

  const configRef = db.doc('config/main');
  const configSnapshot = await configRef.get();
  let configCreated = false;

  if (!configSnapshot.exists) {
    await configRef.set({
      ...defaults,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    configCreated = true;
  } else {
    const current = configSnapshot.data() ?? {};
    const patch = {};
    for (const [key, value] of Object.entries(defaults)) {
      if (current[key] === undefined) patch[key] = value;
    }
    if (Object.keys(patch).length > 0) {
      await configRef.set(
        { ...patch, updatedAt: FieldValue.serverTimestamp() },
        { merge: true },
      );
    }
  }

  const finalConfig = await configRef.get();
  const checkinCode = String(finalConfig.get('checkinCode') ?? '');

  console.log('\n✔ Administrador listo\n');
  console.log(`  Cuenta:        ${created ? 'creada' : 'actualizada'}`);
  console.log(`  Email:         ${email}`);
  console.log(`  Nombre:        ${displayName}`);
  console.log(`  UID:           ${user.uid}`);
  console.log(`  Documento:     admins/${user.uid}`);
  console.log(`  Claim:         admin=true, role=admin`);
  console.log(
    `  Config:        ${configCreated ? 'config/main creada' : 'config/main ya existía'}`,
  );
  console.log(`  Código QR:     ${checkinCode || '(sin código)'}`);
  console.log(
    `  Proyecto:      ${projectId ?? getApps()[0]?.options.projectId ?? '(inferido)'}`,
  );
  console.log(
    '\nSi el administrador ya tenía una sesión abierta, ciérrala y vuelve a entrar para refrescar los claims.\n',
  );
}

main().catch((error) => {
  console.error('\n✖ Error al crear el administrador:\n');
  console.error(error);
  console.error(
    '\nComprueba las credenciales (GOOGLE_APPLICATION_CREDENTIALS, gcloud auth application-default login o --service-account).\n',
  );
  process.exitCode = 1;
});

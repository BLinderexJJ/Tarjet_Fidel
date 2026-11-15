import { FieldValue, Timestamp } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  CALLABLE_OPTIONS,
  auth,
  db,
} from './firebase';
import {
  CONFIG_REF,
  DEFAULT_MAX_USERS,
  DEFAULT_STAMPS_GOAL,
  readConfigData,
  readPositiveInt,
  readString,
} from './config';
import { requireAdmin, requireAuth } from './security';
import { assertTrialActive, getTrialStatus } from './trial';
import {
  normalizeCheckinCode,
  parseApproveInput,
  parseId,
  parseRegisterInput,
  parseStampCode,
} from './validation';

/** Máximo de solicitudes por cliente en la ventana indicada. */
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW_MS = 24 * 60 * 60 * 1000;

function isAuthError(error: unknown, code: string): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === code
  );
}

function asNumber(value: unknown, fallback = 0): number {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

/**
 * Registra un cliente sin requerir sesión previa.
 *
 * La cuenta se crea con el Admin SDK usando el correo sintético
 * `cliente_<username>@tarjetfidel.local`. Firebase Auth garantiza la
 * unicidad del correo, lo que evita duplicados incluso con solicitudes
 * simultáneas. Si falla la creación del perfil, se revierte la cuenta.
 */
export const registerClient = onCall(CALLABLE_OPTIONS, async (request) => {
  const input = parseRegisterInput(request.data);
  const username = input.username.toLowerCase();

  await assertTrialActive();

  const existing = await db
    .collection('users')
    .where('usernameLower', '==', username)
    .limit(1)
    .get();

  if (!existing.empty) {
    throw new HttpsError('already-exists', 'username_taken');
  }

  const config = await readConfigData();
  const maxUsers = readPositiveInt(config, 'maxUsers', DEFAULT_MAX_USERS);
  const clientCount = await db
    .collection('users')
    .where('role', '==', 'client')
    .count()
    .get();

  if (clientCount.data().count >= maxUsers) {
    throw new HttpsError('resource-exhausted', 'limit_reached');
  }

  const internalEmail = `cliente_${username}@tarjetfidel.local`;

  let uid: string;
  try {
    const userRecord = await auth.createUser({
      email: internalEmail,
      password: input.password,
      displayName: input.displayName,
      emailVerified: false,
      disabled: false,
    });
    uid = userRecord.uid;
  } catch (error) {
    if (isAuthError(error, 'auth/email-already-exists')) {
      throw new HttpsError('already-exists', 'username_taken');
    }
    logger.error('No se pudo crear la cuenta de Auth.', error);
    throw new HttpsError('internal', 'internal');
  }

  try {
    await auth.setCustomUserClaims(uid, { role: 'client' });
    await db.collection('users').doc(uid).create({
      username,
      usernameLower: username,
      internalEmail,
      displayName: input.displayName,
      currentStamps: 0,
      totalVisits: 0,
      role: 'client',
      isRewardReady: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    await auth.deleteUser(uid).catch((cleanupError: unknown) => {
      logger.error('No se pudo revertir la cuenta huérfana.', cleanupError);
    });
    logger.error('No se pudo crear el perfil del cliente.', error);
    throw new HttpsError('internal', 'internal');
  }

  return { uid };
});

/**
 * Crea una solicitud `pending` para que el administrador la apruebe.
 *
 * El QR nunca otorga sellos directamente. Además se aplican:
 * - verificación del código vigente en `config/main.checkinCode`;
 * - anti-duplicado (una sola solicitud pendiente por cliente);
 * - límite de 10 solicitudes por cliente cada 24 horas;
 * - comprobación de la prueba del negocio.
 */
export const createStampRequest = onCall(CALLABLE_OPTIONS, async (request) => {
  const uid = requireAuth(request);
  const code = parseStampCode(request.data);

  await assertTrialActive();

  const userRef = db.collection('users').doc(uid);
  const userSnapshot = await userRef.get();

  if (!userSnapshot.exists) {
    throw new HttpsError('failed-precondition', 'user_not_found');
  }
  if (userSnapshot.get('role') !== 'client') {
    throw new HttpsError('permission-denied', 'client_only');
  }

  const userData = userSnapshot.data() ?? {};
  const userName =
    readString(userData, 'displayName').trim() ||
    readString(userData, 'username').trim() ||
    'Cliente';

  const config = await readConfigData();
  const expectedCode = normalizeCheckinCode(
    readString(config, 'checkinCode'),
  );

  if (!expectedCode || expectedCode !== code) {
    throw new HttpsError('invalid-argument', 'invalid_code');
  }

  const requestId = await db.runTransaction(async (transaction) => {
    const pending = await transaction.get(
      db
        .collection('stamp_requests')
        .where('userId', '==', uid)
        .where('status', '==', 'pending')
        .limit(1),
    );

    if (!pending.empty) {
      throw new HttpsError('failed-precondition', 'pending_exists');
    }

    const recent = await transaction.get(
      db
        .collection('stamp_requests')
        .where('userId', '==', uid)
        .orderBy('createdAt', 'desc')
        .limit(RATE_LIMIT_MAX),
    );

    const cutoff = Date.now() - RATE_LIMIT_WINDOW_MS;
    const withinWindow = recent.docs.filter((doc) => {
      const createdAt = doc.get('createdAt');
      return (
        createdAt instanceof Timestamp &&
        createdAt.toMillis() >= cutoff
      );
    }).length;

    if (withinWindow >= RATE_LIMIT_MAX) {
      throw new HttpsError('resource-exhausted', 'rate_limited');
    }

    const requestRef = db.collection('stamp_requests').doc();
    transaction.create(requestRef, {
      userId: uid,
      userName,
      status: 'pending',
      stampsAwarded: 1,
      createdAt: FieldValue.serverTimestamp(),
    });

    return requestRef.id;
  });

  return { requestId };
});

/** Aprueba una solicitud y suma los sellos de forma atómica. */
export const approveStampRequest = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    const adminUid = await requireAdmin(request);
    const input = parseApproveInput(request.data);

    await assertTrialActive();

    const requestRef = db.collection('stamp_requests').doc(input.requestId);

    const result = await db.runTransaction(async (transaction) => {
      const configSnapshot = await transaction.get(CONFIG_REF);
      const requestSnapshot = await transaction.get(requestRef);

      if (!requestSnapshot.exists) {
        throw new HttpsError('not-found', 'not_found');
      }

      const status = readString(requestSnapshot.data() ?? {}, 'status');
      if (status === 'approved') {
        throw new HttpsError('failed-precondition', 'already_approved');
      }
      if (status !== 'pending') {
        throw new HttpsError('failed-precondition', 'request_not_pending');
      }

      const userId = readString(requestSnapshot.data() ?? {}, 'userId');
      if (!userId) {
        throw new HttpsError('failed-precondition', 'user_not_found');
      }

      const userRef = db.collection('users').doc(userId);
      const userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw new HttpsError('not-found', 'user_not_found');
      }

      const config = configSnapshot.data() ?? {};
      const goal = readPositiveInt(
        config,
        'stampsGoal',
        DEFAULT_STAMPS_GOAL,
        100,
      );
      const currentStamps = asNumber(userSnapshot.get('currentStamps'));
      const totalVisits = asNumber(userSnapshot.get('totalVisits'));
      const newStamps = currentStamps + input.stampsAwarded;
      const isRewardReady = newStamps >= goal;

      transaction.update(userRef, {
        currentStamps: newStamps,
        totalVisits: totalVisits + 1,
        isRewardReady,
        updatedAt: FieldValue.serverTimestamp(),
      });

      transaction.set(db.collection('visits').doc(), {
        userId,
        stamps: input.stampsAwarded,
        approvedBy: adminUid,
        requestId: input.requestId,
        timestamp: FieldValue.serverTimestamp(),
      });

      transaction.update(requestRef, {
        status: 'approved',
        stampsAwarded: input.stampsAwarded,
        approvedAt: FieldValue.serverTimestamp(),
        approvedBy: adminUid,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return { currentStamps: newStamps, isRewardReady };
    });

    return { ok: true, ...result };
  },
);

/** Rechaza una solicitud pendiente. */
export const rejectStampRequest = onCall(
  CALLABLE_OPTIONS,
  async (request) => {
    const adminUid = await requireAdmin(request);
    const requestId = parseId(request.data, 'requestId');
    const requestRef = db.collection('stamp_requests').doc(requestId);

    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(requestRef);

      if (!snapshot.exists) {
        throw new HttpsError('not-found', 'not_found');
      }

      const status = readString(snapshot.data() ?? {}, 'status');
      if (status !== 'pending') {
        throw new HttpsError('failed-precondition', 'request_not_pending');
      }

      transaction.update(requestRef, {
        status: 'rejected',
        rejectedAt: FieldValue.serverTimestamp(),
        rejectedBy: adminUid,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return { ok: true };
  },
);

/**
 * Canjea el premio de un cliente: reinicia sus sellos y deja un registro
 * inmutable en `redemptions`.
 */
export const resetStamps = onCall(CALLABLE_OPTIONS, async (request) => {
  const adminUid = await requireAdmin(request);
  const userId = parseId(request.data, 'userId');
  const userRef = db.collection('users').doc(userId);

  const result = await db.runTransaction(async (transaction) => {
    const configSnapshot = await transaction.get(CONFIG_REF);
    const userSnapshot = await transaction.get(userRef);

    if (!userSnapshot.exists) {
      throw new HttpsError('not-found', 'user_not_found');
    }

    const data = userSnapshot.data() ?? {};
    const stampsBefore = asNumber(data.currentStamps);
    const userName =
      readString(data, 'displayName').trim() ||
      readString(data, 'username').trim() ||
      'Cliente';

    transaction.update(userRef, {
      currentStamps: 0,
      isRewardReady: false,
      updatedAt: FieldValue.serverTimestamp(),
    });

    transaction.set(db.collection('redemptions').doc(), {
      userId,
      userName,
      stampsBefore,
      rewardDescription: readString(
        configSnapshot.data() ?? {},
        'rewardDescription',
      ),
      redeemedBy: adminUid,
      timestamp: FieldValue.serverTimestamp(),
    });

    return { stampsBefore };
  });

  return { ok: true, ...result };
});

/**
 * Estado de la prueba calculado en el servidor. Se puede llamar sin sesión
 * para que la pantalla de acceso pueda informar del bloqueo si se desea.
 */
export const checkTrialStatus = onCall(CALLABLE_OPTIONS, async () => {
  return getTrialStatus();
});

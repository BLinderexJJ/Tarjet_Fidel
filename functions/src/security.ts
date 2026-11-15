import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

import { db } from './firebase';

export function requireAuth(request: CallableRequest): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'unauthenticated');
  }
  return uid;
}

/**
 * Un administrador es quien tiene el claim `admin: true` o, como respaldo,
 * un documento en `admins/{uid}`. El panel usa el documento como fuente de
 * verdad, así que se comprueba primero para que revocar el documento surta
 * efecto aunque el token conserve el claim.
 */
export async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = requireAuth(request);
  const adminDoc = await db.doc(`admins/${uid}`).get();
  if (adminDoc.exists) return uid;
  if (request.auth?.token.admin === true) return uid;
  throw new HttpsError('permission-denied', 'admin_only');
}

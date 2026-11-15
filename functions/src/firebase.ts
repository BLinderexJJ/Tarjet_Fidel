import { getApp, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

/**
 * La base `(default)` exige plan Blaze para crearse por API; el proyecto usa la
 * base con nombre `default`, que sí existe en el plan Spark. Debe coincidir con
 * `AppConfig.firestoreDatabaseId` y con `firestore.database` de `firebase.json`.
 */
export const FIRESTORE_DATABASE_ID = 'default';

if (getApps().length === 0) {
  initializeApp();
}

export const db = getFirestore(getApp(), FIRESTORE_DATABASE_ID);
export const auth = getAuth();

/** Debe coincidir con `AppConfig.functionsRegion` del cliente Flutter. */
export const REGION = 'us-central1';

/**
 * La verificación de App Check se activa con `ENFORCE_APP_CHECK=true` en
 * `functions/.env`, una vez registrada la app web y compilada con la site key.
 */
export const ENFORCE_APP_CHECK = process.env.ENFORCE_APP_CHECK === 'true';

export const CALLABLE_OPTIONS = {
  region: REGION,
  enforceAppCheck: ENFORCE_APP_CHECK,
  // Las callables validan la sesión (y opcionalmente App Check) dentro de la
  // función, por lo que Cloud Run debe permitir la invocación pública.
  invoker: 'public',
} as const;

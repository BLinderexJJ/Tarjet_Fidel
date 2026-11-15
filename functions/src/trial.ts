import { getRemoteConfig } from 'firebase-admin/remote-config';
import * as logger from 'firebase-functions/logger';
import { HttpsError } from 'firebase-functions/v2/https';

import { readString, readConfigData } from './config';

export interface TrialStatus {
  active: boolean;
  expiryDate: string | null;
  daysRemaining: number | null;
}

const CACHE_MS = 5 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

let cache: { value: string | null; at: number } | null = null;

/**
 * Lee `trial_expiry_date` de Remote Config. Si Remote Config no está
 * disponible, usa el espejo `config/main.trialExpiryDate`. El valor se cachea
 * 5 minutos para no llamar a la API en cada solicitud.
 */
async function readRawExpiry(): Promise<string | null> {
  const now = Date.now();
  if (cache && now - cache.at < CACHE_MS) return cache.value;

  let value: string | null = null;

  try {
    const template = await getRemoteConfig().getTemplate();
    const parameter = template.parameters?.['trial_expiry_date']?.defaultValue;
    if (parameter && 'value' in parameter) {
      const raw = parameter.value;
      if (typeof raw === 'string' && raw.trim()) value = raw.trim();
    }
  } catch (error) {
    logger.warn(
      'No se pudo leer Remote Config; se intentará el espejo en Firestore.',
      error,
    );
  }

  if (!value) {
    try {
      const config = await readConfigData();
      const raw = readString(config, 'trialExpiryDate').trim();
      if (raw) value = raw;
    } catch (error) {
      logger.warn('No se pudo leer trialExpiryDate de Firestore.', error);
    }
  }

  cache = { value, at: now };
  return value;
}

export async function getTrialStatus(): Promise<TrialStatus> {
  const raw = await readRawExpiry();
  if (!raw) {
    return { active: true, expiryDate: null, daysRemaining: null };
  }

  const expiry = new Date(raw);
  if (Number.isNaN(expiry.getTime())) {
    logger.warn(`trial_expiry_date no es una fecha ISO válida: "${raw}"`);
    return { active: true, expiryDate: null, daysRemaining: null };
  }

  const remaining = expiry.getTime() - Date.now();
  const active = remaining > 0;

  return {
    active,
    expiryDate: expiry.toISOString(),
    daysRemaining: active ? Math.ceil(remaining / DAY_MS) : 0,
  };
}

/** Lanza `trial_expired` si la prueba terminó. */
export async function assertTrialActive(): Promise<void> {
  const status = await getTrialStatus();
  if (!status.active) {
    throw new HttpsError('failed-precondition', 'trial_expired');
  }
}

import { db } from './firebase';

export const CONFIG_REF = db.doc('config/main');

export const DEFAULT_STAMPS_GOAL = 10;
export const DEFAULT_MAX_USERS = 50;

export type ConfigData = Record<string, unknown>;

export async function readConfigData(): Promise<ConfigData> {
  const snapshot = await CONFIG_REF.get();
  return snapshot.exists ? (snapshot.data() as ConfigData) : {};
}

/** Lee un entero positivo, con respaldo y límite superior opcional. */
export function readPositiveInt(
  data: ConfigData,
  key: string,
  fallback: number,
  max = Number.MAX_SAFE_INTEGER,
): number {
  const raw = data[key];
  const value = typeof raw === 'number' ? raw : Number(raw);
  if (!Number.isFinite(value) || value < 1) return fallback;
  return Math.min(Math.floor(value), max);
}

export function readString(
  data: ConfigData,
  key: string,
  fallback = '',
): string {
  const raw = data[key];
  return typeof raw === 'string' ? raw : fallback;
}

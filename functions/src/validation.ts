import { HttpsError } from 'firebase-functions/v2/https';
import { z } from 'zod';

/**
 * Primera letra alfanumérica y entre 2 y 31 caracteres adicionales:
 * longitud total entre 3 y 32. Debe coincidir con `AuthService` en Dart.
 */
const USERNAME_PATTERN = /^[a-zA-Z0-9](?:[a-zA-Z0-9._-]{2,31})$/;
const PASSWORD_PATTERN = /^\d{6}$/;

const registerSchema = z.object({
  username: z.string().trim().min(3).max(32).regex(USERNAME_PATTERN),
  password: z.string().regex(PASSWORD_PATTERN),
  displayName: z.string().trim().min(1).max(60),
});

const stampCodeSchema = z.object({
  code: z.string().trim().min(1).max(256),
});

const approveSchema = z.object({
  requestId: z.string().trim().min(1).max(128),
  stampsAwarded: z.number().int().min(1).max(100).default(1),
});

const idSchema = z.object({
  requestId: z.string().trim().min(1).max(128).optional(),
  userId: z.string().trim().min(1).max(128).optional(),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type ApproveInput = z.infer<typeof approveSchema>;

function firstIssueField(error: z.ZodError): string {
  const path = error.issues[0]?.path;
  return path && path.length > 0 ? String(path[0]) : '';
}

export function parseRegisterInput(data: unknown): RegisterInput {
  const result = registerSchema.safeParse(data);
  if (!result.success) {
    const field = firstIssueField(result.error);
    const key =
      field === 'username'
        ? 'invalid_username'
        : field === 'password'
          ? 'invalid_password'
          : 'invalid_input';
    throw new HttpsError('invalid-argument', key);
  }
  return result.data;
}

/** Devuelve el código de check-in ya normalizado (mayúsculas, sin prefijo). */
export function parseStampCode(data: unknown): string {
  const result = stampCodeSchema.safeParse(data);
  if (!result.success) {
    throw new HttpsError('invalid-argument', 'invalid_code');
  }
  const code = normalizeCheckinCode(result.data.code);
  if (!code) {
    throw new HttpsError('invalid-argument', 'invalid_code');
  }
  return code;
}

export function parseApproveInput(data: unknown): ApproveInput {
  const result = approveSchema.safeParse(data);
  if (!result.success) {
    throw new HttpsError('invalid-argument', 'invalid_input');
  }
  return result.data;
}

export function parseId(data: unknown, field: 'requestId' | 'userId'): string {
  const result = idSchema.safeParse(data);
  if (!result.success || !result.data[field]) {
    throw new HttpsError('invalid-argument', 'invalid_input');
  }
  return result.data[field] as string;
}

/**
 * Acepta `TARJET:XXXX`, una URL con `?code=XXXX` o el código directo.
 * Misma lógica que `normalizeCheckinCode` en `lib/utils/codes.dart`.
 */
export function normalizeCheckinCode(raw: string): string {
  let value = raw.trim();
  if (!value) return '';

  if (value.toLowerCase().startsWith('tarjet:')) {
    value = value.slice('tarjet:'.length).trim();
  }

  try {
    const url = new URL(value);
    const fromQuery = url.searchParams.get('code');
    if (fromQuery) value = fromQuery.trim();
  } catch {
    // No es una URL: se usa el valor tal cual.
  }

  return value.toUpperCase();
}

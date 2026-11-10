import crypto from 'node:crypto';
import { createRemoteJWKSet, jwtVerify } from 'jose';

// Chaves públicas que o Google usa para assinar os ID tokens.
const GOOGLE_JWKS = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));
const GOOGLE_ISSUERS = ['https://accounts.google.com', 'accounts.google.com'];

/** Domínio institucional liberado por padrão (contas de servidores do IFCE). */
export const DEFAULT_ALLOWED_DOMAIN = 'ifce.edu.br';

/**
 * Só passa conta do Google Workspace do domínio exato: o Google informa o
 * domínio no campo "hd" do token, então um Gmail comum ou um subdomínio
 * (ex.: alunos) não passa.
 */
export function isAllowedGoogleAccount(payload, allowedDomain) {
  if (!payload || payload.email_verified !== true) return false;
  if (typeof payload.hd !== 'string' || payload.hd.toLowerCase() !== allowedDomain) return false;
  return typeof payload.email === 'string' && payload.email.toLowerCase().endsWith(`@${allowedDomain}`);
}

// Comparação em tempo constante para não vazar o token por timing.
export function tokenMatches(received, expected) {
  const a = crypto.createHash('sha256').update(String(received)).digest();
  const b = crypto.createHash('sha256').update(String(expected)).digest();
  return crypto.timingSafeEqual(a, b);
}

/** Lê as configurações de autenticação das variáveis de ambiente. */
export function authConfig(env = process.env) {
  const googleClientId = (env.GOOGLE_CLIENT_ID || '').trim();
  const allowedDomain = (env.EMAIL_ALLOWED_DOMAIN || DEFAULT_ALLOWED_DOMAIN).trim().toLowerCase().replace(/^@/, '');
  return {
    googleClientId,
    allowedDomain,
    apiToken: env.EMAIL_API_TOKEN || '',
    googleEnabled: Boolean(googleClientId),
  };
}

/** Valida um ID token do Google e devolve o conteúdo dele. */
export async function verifyGoogleIdToken(idToken, clientId) {
  const { payload } = await jwtVerify(idToken, GOOGLE_JWKS, {
    issuer: GOOGLE_ISSUERS,
    audience: clientId,
  });
  return payload;
}

const looksLikeJwt = (value) => value.split('.').length === 3;

/**
 * Decide se quem chama o /api/email pode enviar. Aceita:
 *  - o ID token do botão "Entrar com Google", de conta do domínio liberado
 *    (padrão: ifce.edu.br); ou
 *  - o código de acesso antigo (EMAIL_API_TOKEN), se ele estiver configurado.
 *
 * Devolve `{ ok: true, user }` ou `{ ok: false, status, error }`.
 */
export async function authorizeRequest(authorizationHeader, config, verify = verifyGoogleIdToken) {
  const header = authorizationHeader || '';
  const received = header.startsWith('Bearer ') ? header.slice(7).trim() : '';
  if (!received) {
    return { ok: false, status: 401, error: 'Entre com o Google (ou informe o código de acesso) para enviar.' };
  }

  if (config.googleEnabled && looksLikeJwt(received)) {
    let payload;
    try {
      payload = await verify(received, config.googleClientId);
    } catch {
      return { ok: false, status: 401, error: 'Sessão do Google expirada ou inválida. Entre de novo com o Google.' };
    }
    if (!isAllowedGoogleAccount(payload, config.allowedDomain)) {
      const who = payload.email ? `A conta ${payload.email}` : 'Esta conta';
      return {
        ok: false,
        status: 403,
        error: `${who} não pode enviar certificados. Use uma conta @${config.allowedDomain}.`,
      };
    }
    return { ok: true, user: payload.email };
  }

  if (config.apiToken && tokenMatches(received, config.apiToken)) {
    return { ok: true, user: 'codigo-de-acesso' };
  }
  return { ok: false, status: 401, error: 'Código de acesso inválido.' };
}

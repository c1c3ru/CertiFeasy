import { test } from 'node:test';
import assert from 'node:assert/strict';
import { authConfig, authorizeRequest, isAllowedGoogleAccount } from '../../api/_lib/auth.js';

const JWT = 'header.payload.signature';
const googleConfig = authConfig({ GOOGLE_CLIENT_ID: 'cliente.apps.googleusercontent.com' });

const fakeVerify = (payload) => async (token, clientId) => {
  assert.equal(token, JWT);
  assert.equal(clientId, 'cliente.apps.googleusercontent.com');
  return payload;
};

const servidor = { email: 'cicero@ifce.edu.br', email_verified: true, hd: 'ifce.edu.br' };

test('login com Google fica ativo só com o client ID; domínio padrão é ifce.edu.br', () => {
  assert.equal(googleConfig.googleEnabled, true);
  assert.equal(googleConfig.allowedDomain, 'ifce.edu.br');
  assert.equal(authConfig({}).googleEnabled, false);
  assert.equal(authConfig({ EMAIL_ALLOWED_DOMAIN: '@Outro.edu.br' }).allowedDomain, 'outro.edu.br');
});

test('só aceita conta do domínio exato, com e-mail verificado', () => {
  assert.equal(isAllowedGoogleAccount(servidor, 'ifce.edu.br'), true);
  // Alunos usam outro domínio (subdomínio): não passam.
  assert.equal(isAllowedGoogleAccount({ ...servidor, email: 'a@aluno.ifce.edu.br', hd: 'aluno.ifce.edu.br' }, 'ifce.edu.br'), false);
  // Gmail comum não tem "hd".
  assert.equal(isAllowedGoogleAccount({ email: 'x@gmail.com', email_verified: true }, 'ifce.edu.br'), false);
  // E-mail sem "hd" não basta, mesmo terminando em @ifce.edu.br.
  assert.equal(isAllowedGoogleAccount({ email: 'x@ifce.edu.br', email_verified: true }, 'ifce.edu.br'), false);
  assert.equal(isAllowedGoogleAccount({ ...servidor, email_verified: false }, 'ifce.edu.br'), false);
});

test('aceita ID token de servidor @ifce.edu.br', async () => {
  const result = await authorizeRequest(`Bearer ${JWT}`, googleConfig, fakeVerify(servidor));
  assert.deepEqual(result, { ok: true, user: 'cicero@ifce.edu.br' });
});

test('recusa conta de aluno ou de fora com 403', async () => {
  const aluno = await authorizeRequest(
    `Bearer ${JWT}`,
    googleConfig,
    fakeVerify({ email: 'fulano@aluno.ifce.edu.br', email_verified: true, hd: 'aluno.ifce.edu.br' }),
  );
  assert.equal(aluno.ok, false);
  assert.equal(aluno.status, 403);
  assert.match(aluno.error, /fulano@aluno\.ifce\.edu\.br/);
  assert.match(aluno.error, /@ifce\.edu\.br/);
});

test('token do Google inválido ou expirado devolve 401', async () => {
  const result = await authorizeRequest(`Bearer ${JWT}`, googleConfig, async () => {
    throw new Error('"exp" claim timestamp check failed');
  });
  assert.equal(result.status, 401);
  assert.match(result.error, /Entre de novo/);
});

test('código de acesso antigo continua funcionando quando configurado', async () => {
  const config = authConfig({ EMAIL_API_TOKEN: 'segredo' });
  assert.deepEqual(await authorizeRequest('Bearer segredo', config), { ok: true, user: 'codigo-de-acesso' });
  assert.equal((await authorizeRequest('Bearer errado', config)).status, 401);
});

test('sem Authorization ou sem código configurado, recusa', async () => {
  assert.equal((await authorizeRequest(undefined, googleConfig)).status, 401);
  assert.equal((await authorizeRequest('Bearer segredo', googleConfig)).ok, false);
});

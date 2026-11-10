import { authConfig } from './_lib/auth.js';

// Configuração pública que o app lê ao abrir: o ID de cliente OAuth do Google
// não é segredo (ele aparece no botão "Entrar com Google" de qualquer site).
export default function handler(req, res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET');
    return res.status(405).json({ error: 'Method not allowed' });
  }
  const config = authConfig();
  res.setHeader('Cache-Control', 'no-store');
  return res.status(200).json({
    googleClientId: config.googleEnabled ? config.googleClientId : null,
    allowedDomain: config.allowedDomain,
  });
}

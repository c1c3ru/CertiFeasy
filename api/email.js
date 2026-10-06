import crypto from 'node:crypto';
import nodemailer from 'nodemailer';

// Limites do endpoint. O corpo das funções da Vercel é limitado a ~4,5 MB,
// e o anexo chega em base64 (~33% maior que o PDF original).
const MAX_ATTACHMENT_BYTES = 3 * 1024 * 1024;
const MAX_SUBJECT_LENGTH = 200;
const MAX_TEXT_LENGTH = 10000;
const MAX_FILENAME_LENGTH = 120;
const EMAIL_REGEX = /^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$/;

function isValidEmail(value) {
  return typeof value === 'string' && value.length <= 254 && EMAIL_REGEX.test(value);
}

// Comparação em tempo constante para não vazar o token por timing.
function tokenMatches(received, expected) {
  const a = crypto.createHash('sha256').update(String(received)).digest();
  const b = crypto.createHash('sha256').update(String(expected)).digest();
  return crypto.timingSafeEqual(a, b);
}

function isAllowedOrigin(origin) {
  // Requisições sem Origin (apps desktop/mobile) passam; a proteção real é o token.
  if (!origin) return true;
  const allowed = (process.env.EMAIL_ALLOWED_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);
  if (allowed.length === 0) return true;
  return allowed.includes(origin);
}

function badRequest(res, message) {
  return res.status(400).json({ error: message });
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const gmailUser = process.env.GMAIL_USER;
  const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;
  const apiToken = process.env.EMAIL_API_TOKEN;

  if (!gmailUser || !gmailAppPassword || !apiToken) {
    console.error('email: variáveis GMAIL_USER, GMAIL_APP_PASSWORD ou EMAIL_API_TOKEN ausentes');
    return res.status(503).json({ error: 'Envio de e-mails não configurado no servidor.' });
  }

  if (!isAllowedOrigin(req.headers.origin)) {
    return res.status(403).json({ error: 'Origem não permitida.' });
  }

  const auth = req.headers.authorization || '';
  const received = auth.startsWith('Bearer ') ? auth.slice(7).trim() : '';
  if (!received || !tokenMatches(received, apiToken)) {
    return res.status(401).json({ error: 'Código de acesso inválido.' });
  }

  const { to, replyTo, subject, text, attachments } = req.body || {};

  // Um destinatário por requisição: o app envia um certificado por pessoa.
  const recipient = Array.isArray(to) ? (to.length === 1 ? to[0] : null) : to;
  if (!isValidEmail(recipient)) {
    return badRequest(res, 'Destinatário inválido.');
  }
  if (replyTo !== undefined && replyTo !== '' && !isValidEmail(replyTo)) {
    return badRequest(res, 'E-mail de resposta inválido.');
  }
  if (typeof subject !== 'string' || subject.length === 0 || subject.length > MAX_SUBJECT_LENGTH) {
    return badRequest(res, 'Assunto inválido.');
  }
  if (typeof text !== 'string' || text.length > MAX_TEXT_LENGTH) {
    return badRequest(res, 'Corpo do e-mail inválido.');
  }
  if (!Array.isArray(attachments) || attachments.length !== 1) {
    return badRequest(res, 'Envie exatamente um anexo.');
  }

  const [attachment] = attachments;
  if (
    !attachment ||
    typeof attachment.filename !== 'string' ||
    typeof attachment.content !== 'string'
  ) {
    return badRequest(res, 'Anexo inválido.');
  }
  const filename = attachment.filename
    .replace(/[^\p{L}\p{N}_\-. ]/gu, '_')
    .slice(0, MAX_FILENAME_LENGTH);
  if (!filename.toLowerCase().endsWith('.pdf')) {
    return badRequest(res, 'O anexo deve ser um PDF.');
  }
  const content = Buffer.from(attachment.content, 'base64');
  if (content.length === 0 || content.length > MAX_ATTACHMENT_BYTES) {
    return badRequest(res, 'Anexo vazio ou maior que 3 MB.');
  }
  if (content.subarray(0, 5).toString('latin1') !== '%PDF-') {
    return badRequest(res, 'O anexo deve ser um PDF.');
  }

  try {
    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: gmailAppPassword,
      },
    });

    await transporter.sendMail({
      from: `CTI-Maracanau IFCE <${gmailUser}>`,
      to: recipient,
      replyTo: replyTo || gmailUser,
      subject,
      text,
      attachments: [{ filename, content, contentType: 'application/pdf' }],
    });

    return res.status(200).json({ id: 'sent', message: 'Email sent successfully' });
  } catch (error) {
    console.error('email: falha ao enviar', error);
    return res.status(502).json({ error: 'Falha ao enviar o e-mail. Tente novamente mais tarde.' });
  }
}

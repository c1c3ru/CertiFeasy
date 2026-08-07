export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const apiKey = process.env.RESEND_API_KEY;

    if (!apiKey) {
      return res.status(500).json({ error: 'Server configuration error: Missing API Key' });
    }

    // Parse body to inject sender overrides
    const body = req.body;

    // Capture original sender for reply_to
    const originalSender = body.from || 'cti.maracanau@ifce.edu.br';

    // Override from with verified Resend domain, set reply_to to original
    const payload = {
      ...body,
      from: 'CertifEasy CTI-Maracanau <onboarding@resend.dev>',
      reply_to: originalSender,
    };

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });

    const data = await response.json();

    if (!response.ok) {
      return res.status(response.status).json(data);
    }

    return res.status(200).json(data);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}

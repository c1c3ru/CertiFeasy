import nodemailer from 'nodemailer';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  try {
    const gmailUser = process.env.GMAIL_USER;
    const gmailAppPassword = process.env.GMAIL_APP_PASSWORD;

    if (!gmailUser || !gmailAppPassword) {
      return res.status(500).json({ error: 'Server configuration error: Missing credentials' });
    }

    const { to, subject, text, attachments } = req.body;

    const transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: gmailUser,
        pass: gmailAppPassword,
      },
    });

    // Convert base64 attachments from Flutter format to nodemailer format
    const nodeAttachments = (attachments || []).map(a => ({
      filename: a.filename,
      content: Buffer.from(a.content, 'base64'),
      encoding: 'base64',
    }));

    const mailOptions = {
      from: `CTI-Maracanau IFCE <${gmailUser}>`,
      to: Array.isArray(to) ? to.join(', ') : to,
      replyTo: gmailUser,
      subject,
      text,
      attachments: nodeAttachments,
    };

    await transporter.sendMail(mailOptions);

    return res.status(200).json({ id: 'sent', message: 'Email sent successfully' });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}

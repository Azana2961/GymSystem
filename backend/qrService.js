const QRCode = require('qrcode');
const path = require('path');
const fs = require('fs');

const QR_DIR = path.join(__dirname, 'public', 'qrcodes');

// Ensure output directory exists
if (!fs.existsSync(QR_DIR)) {
  fs.mkdirSync(QR_DIR, { recursive: true });
}

/**
 * Generates a unique QR token, e.g. "GYM-A7X9K2"
 */
function generateQrToken(prefix = 'GYM') {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let random = '';
  for (let i = 0; i < 6; i++) {
    random += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return `${prefix}-${random}`;
}

/**
 * Generates and saves a high-resolution PNG QR Code to disk,
 * and returns the relative URL + Data URL for immediate display.
 */
async function generateAndSaveQr(token) {
  const fileName = `${token}.png`;
  const filePath = path.join(QR_DIR, fileName);

  // Generate high-contrast black/white QR code
  await QRCode.toFile(filePath, token, {
    errorCorrectionLevel: 'H',
    type: 'png',
    quality: 0.95,
    margin: 2,
    width: 400,
    color: {
      dark: '#000000',
      light: '#FFFFFF',
    },
  });

  const dataUrl = await QRCode.toDataURL(token, {
    errorCorrectionLevel: 'H',
    width: 300,
    margin: 2,
  });

  return {
    filePath,
    fileName,
    url: `/qrcodes/${fileName}`,
    dataUrl,
  };
}

module.exports = {
  generateQrToken,
  generateAndSaveQr,
  QR_DIR,
};

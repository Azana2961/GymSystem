const db = require('./db');
const { generateQrToken, generateAndSaveQr } = require('./qrService');

const INITIAL_MEMBERS = [
  {
    id: 'M001',
    name: 'Muhammad Ali',
    phone: '+92 300 8472910',
    email: 'm.ali@gmail.com',
    plan: 'Gold Plan',
    expiryDays: 30,
    status: 'paid',
    gender: 'Male',
    notes: 'Morning workouts'
  },
  {
    id: 'M002',
    name: 'Ayesha Khan',
    phone: '+92 321 4589211',
    email: 'ayesha.khan@gmail.com',
    plan: 'Silver Plan',
    expiryDays: 4, // Due soon (< 5 days)
    status: 'due',
    gender: 'Female',
    notes: 'Card expiring soon'
  },
  {
    id: 'M003',
    name: 'Hamza Tariq',
    phone: '+92 333 9821450',
    email: 'hamza.tariq@gmail.com',
    plan: 'Platinum Plan',
    expiryDays: 120,
    status: 'paid',
    gender: 'Male',
    notes: 'Personal training client'
  },
  {
    id: 'M004',
    name: 'Usman Khalid',
    phone: '+92 301 7748123',
    email: 'usman.khalid@gmail.com',
    plan: 'Basic Plan',
    expiryDays: -5, // Expired
    status: 'expired',
    gender: 'Male',
    notes: 'Membership overdue'
  },
  {
    id: 'M005',
    name: 'Fatima Noor',
    phone: '+92 345 5612890',
    email: 'fatima.noor@gmail.com',
    plan: 'Gold Plan',
    expiryDays: 45,
    status: 'paid',
    gender: 'Female',
    notes: 'Prefers evening slots'
  },
  {
    id: 'M006',
    name: 'Zainab Bibi',
    phone: '+92 322 3319045',
    email: 'zainab.bibi@gmail.com',
    plan: 'Silver Plan',
    expiryDays: 60,
    status: 'paid',
    gender: 'Female',
    notes: 'Yoga and cardio'
  }
];

function addDays(days) {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return date.toISOString().split('T')[0];
}

async function seed() {
  const currentCount = db.countMembers();
  if (currentCount > 0) {
    console.log(`Database already contains ${currentCount} members. Skipping initial seed.`);
    return;
  }

  console.log('Seeding initial gym members and generating QR Codes...');

  for (const item of INITIAL_MEMBERS) {
    const token = generateQrToken('GYM');
    const { url } = await generateAndSaveQr(token);
    const expiryDate = addDays(item.expiryDays);

    db.insertMember({
      id: item.id,
      name: item.name,
      phone: item.phone,
      email: item.email,
      plan: item.plan,
      expiry_date: expiryDate,
      status: item.status,
      qr_token: token,
      qr_path: url,
      gender: item.gender,
      notes: item.notes,
      created_at: new Date().toISOString()
    });

    console.log(`✓ Added member: ${item.name} (${item.status.toUpperCase()}) -> QR Token: ${token}`);
  }

  console.log('Seeding completed successfully!');
}

module.exports = seed;

if (require.main === module) {
  seed().then(() => process.exit(0));
}

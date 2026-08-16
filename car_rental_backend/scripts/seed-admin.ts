import { PrismaClient, Role } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = bcrypt.hashSync('Admin@123', 10);

  const admin = await prisma.user.upsert({
    where: { phone: '9999999999' },
    update: {
      name: 'Admin Platform',
      email: 'admin@platform.com',
      role: Role.ADMIN,
      passwordHash,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e',
    },
    create: {
      name: 'Admin Platform',
      phone: '9999999999',
      email: 'admin@platform.com',
      role: Role.ADMIN,
      passwordHash,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e',
    },
  });

  console.log(`[OK] Admin user ensured: ID=${admin.id}, Email=${admin.email}, Role=${admin.role}`);
}

main()
  .catch((e) => {
    console.error('Failed to seed admin user:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

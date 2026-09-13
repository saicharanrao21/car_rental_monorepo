const { PrismaClient } = require('@prisma/client');
const Redis = require('ioredis');

const prisma = new PrismaClient();
const redis = new Redis(process.env.REDIS_URL || 'redis://localhost:6379');

async function main() {
  console.log('Ensuring platform operational readiness for live end-to-end testing...');

  // 1. Get or create Mumbai Service Area
  const mumbaiCity = await prisma.supportedCity.findFirst({
    where: { name: { contains: 'Mumbai', mode: 'insensitive' } },
  });

  if (!mumbaiCity) {
    throw new Error('Mumbai supported city not found!');
  }

  let serviceArea = await prisma.serviceArea.findFirst({
    where: { cityId: mumbaiCity.id },
  });

  if (!serviceArea) {
    serviceArea = await prisma.serviceArea.create({
      data: {
        cityId: mumbaiCity.id,
        name: 'Mumbai Central & Suburban Zone',
        normalizedName: 'mumbai-central-suburban-zone',
        status: 'ACTIVE',
        latitude: mumbaiCity.latitude || 19.076,
        longitude: mumbaiCity.longitude || 72.8777,
        radiusMeters: 50000,
        priority: 10,
      },
    });
    console.log('Created Mumbai Service Area:', serviceArea.id);
  } else {
    console.log('Using existing Mumbai Service Area:', serviceArea.id);
  }

  // 2. Assign all vendors to this Service Area and ensure Security Deposit
  const vendors = await prisma.vendor.findMany();
  for (const v of vendors) {
    // VendorServiceArea
    await prisma.vendorServiceArea.upsert({
      where: {
        vendorId_serviceAreaId: {
          vendorId: v.id,
          serviceAreaId: serviceArea.id,
        },
      },
      update: {
        isActive: true,
        isPrimary: true,
      },
      create: {
        vendorId: v.id,
        serviceAreaId: serviceArea.id,
        isPrimary: true,
        isActive: true,
      },
    });

    // VendorSecurityDeposit
    await prisma.vendorSecurityDeposit.upsert({
      where: { vendorId: v.id },
      update: {
        status: 'PAID',
        requiredAmount: 25000.0,
        paidAmount: 25000.0,
        remainingAmount: 0.0,
        heldAt: new Date(),
      },
      create: {
        vendorId: v.id,
        status: 'PAID',
        requiredAmount: 25000.0,
        paidAmount: 25000.0,
        remainingAmount: 0.0,
        heldAt: new Date(),
      },
    });

    console.log(`Configured Vendor ${v.id} (${v.businessName}) with active service area and paid security deposit.`);
  }

  // 3. Assign all cars in Mumbai to this Service Area & ensure ACTIVE/VERIFIED
  const updateResult = await prisma.car.updateMany({
    data: {
      serviceAreaId: serviceArea.id,
      verificationStatus: 'VERIFIED',
      operationalStatus: 'ACTIVE',
      isAvailable: true,
    },
  });
  console.log(`Updated ${updateResult.count} cars with serviceAreaId ${serviceArea.id}`);

  // 4. Invalidate Redis cache for vehicle eligibility
  const keys = await redis.keys('cache:vehicle:eligibility:*');
  if (keys.length > 0) {
    await redis.del(...keys);
    console.log(`Cleared ${keys.length} vehicle eligibility cache keys from Redis.`);
  }
}

main()
  .catch((e) => {
    console.error('Error ensuring operational readiness:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    redis.disconnect();
  });

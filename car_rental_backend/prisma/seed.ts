import { PrismaClient, Role, BusinessType, VerificationStatus, CarCategory, FuelType, TripType } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  // 1. Clean existing data
  await prisma.otpRequest.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.payout.deleteMany();
  await prisma.review.deleteMany();
  await prisma.booking.deleteMany();
  await prisma.car.deleteMany();
  await prisma.document.deleteMany();
  await prisma.vendor.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.commissionConfig.deleteMany();
  await prisma.banner.deleteMany();
  await prisma.platformSettings.deleteMany();
  await prisma.user.deleteMany();

  // 2. Create Platform Settings
  await prisma.platformSettings.create({
    data: {
      id: 'singleton',
      platformName: 'DriveGo',
      logoUrl: null,
      gstNumber: '27AAAAA1111A1Z1',
      supportEmail: 'support@drivego.in',
      supportPhone: '+919876543210',
      appVersion: '1.0.0',
    },
  });

  // 3. Create Admin User
  const adminPasswordHash = bcrypt.hashSync('Admin@123', 10);
  await prisma.user.create({
    data: {
      name: 'Admin Platform',
      phone: '9999999999',
      email: 'admin@platform.com',
      role: Role.ADMIN,
      passwordHash: adminPasswordHash,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e',
    },
  });

  // 4. Create 5 Customer Users
  const customersData = [
    { id: 'c1', name: 'Rahul Sharma', phone: '9876543210', email: 'rahul.sharma@example.com' },
    { id: 'c2', name: 'Priya Patel', phone: '9876543211', email: 'priya.patel@example.com' },
    { id: 'c3', name: 'Vikram Singh', phone: '9876543212', email: 'vikram.singh@example.com' },
    { id: 'c4', name: 'Ananya Iyer', phone: '9876543213', email: 'ananya.iyer@example.com' },
    { id: 'c5', name: 'Rohan Mehta', phone: '9876543214', email: 'rohan.mehta@example.com' },
  ];

  for (const cust of customersData) {
    await prisma.user.create({
      data: {
        id: cust.id,
        name: cust.name,
        phone: cust.phone,
        email: cust.email,
        role: Role.CUSTOMER,
        passwordHash: null,
      },
    });
  }

  // 5. Create 5 Vendors and their User records
  const vendorsData = [
    {
      id: 'v1',
      phone: '9876543001',
      businessName: 'Mumbai Car Rentals',
      ownerName: 'Amit Shah',
      city: 'Mumbai',
      gstNumber: '27AAAAA1111A1Z1',
      bankDetails: 'HDFC Bank - 50100234567890',
      verificationStatus: VerificationStatus.VERIFIED,
      rating: 4.5,
    },
    {
      id: 'v2',
      phone: '9876543002',
      businessName: 'Apex Drive Mumbai',
      ownerName: 'Rajesh Kulkarni',
      city: 'Mumbai',
      gstNumber: '27BBBBB2222B2Z2',
      bankDetails: 'ICICI Bank - 000401234567',
      verificationStatus: VerificationStatus.VERIFIED,
      rating: 4.2,
    },
    {
      id: 'v5',
      phone: '9876543005',
      businessName: 'Delhi Travel Solutions',
      ownerName: 'Sanjay Gupta',
      city: 'Delhi',
      gstNumber: '07DDDDD4444D4Z4',
      bankDetails: 'Axis Bank - 912010023456789',
      verificationStatus: VerificationStatus.VERIFIED,
      rating: 4.3,
    },
    {
      id: 'v9',
      phone: '9876543009',
      businessName: 'Silicon Valley Drives',
      ownerName: 'Karthik Raja',
      city: 'Bangalore',
      gstNumber: '29GGGGG7777G7Z7',
      bankDetails: 'Kotak Bank - 1234567890',
      verificationStatus: VerificationStatus.VERIFIED,
      rating: 4.8,
    },
    {
      id: 'v13',
      phone: '9876543013',
      businessName: 'Coromandel Rent-a-Car',
      ownerName: 'Srinivasan K.',
      city: 'Chennai',
      gstNumber: '33JJJJJ0000J0Z0',
      bankDetails: 'Indian Bank - 6012345678',
      verificationStatus: VerificationStatus.VERIFIED,
      rating: 4.4,
    },
  ];

  for (const ven of vendorsData) {
    const user = await prisma.user.create({
      data: {
        id: `u_${ven.id}`,
        name: ven.ownerName,
        phone: ven.phone,
        email: `${ven.ownerName.toLowerCase().replace(' ', '.')}@vendor.com`,
        role: Role.VENDOR,
      },
    });

    await prisma.vendor.create({
      data: {
        id: ven.id,
        userId: user.id,
        businessName: ven.businessName,
        ownerName: ven.ownerName,
        city: ven.city,
        gstNumber: ven.gstNumber,
        panNumber: 'ABCDE1234F',
        bankDetails: ven.bankDetails,
        businessType: BusinessType.INDIVIDUAL,
        yearsInOperation: 5,
        verificationStatus: ven.verificationStatus,
        rating: ven.rating,
      },
    });
  }

  // 6. Create ~10 Cars
  const carsData = [
    {
      id: 'car1',
      vendorId: 'v1',
      make: 'Maruti Suzuki',
      model: 'Swift',
      year: 2022,
      type: CarCategory.HATCHBACK,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'MH01AB1234',
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: 14.0,
      pricePerDay: 1700.0,
      pricePerHour: 140.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    },
    {
      id: 'car2',
      vendorId: 'v1',
      make: 'Mahindra',
      model: 'XUV700',
      year: 2022,
      type: CarCategory.SUV,
      fuelType: FuelType.DIESEL,
      seating: 7,
      isAC: true,
      registrationNumber: 'MH01CD5678',
      photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
      pricePerKm: 21.0,
      pricePerDay: 4000.0,
      pricePerHour: 350.0,
      availableTripTypes: [TripType.OUTSTATION, TripType.AIRPORT_TRANSFER],
    },
    {
      id: 'car3',
      vendorId: 'v2',
      make: 'Honda',
      model: 'City',
      year: 2021,
      type: CarCategory.SEDAN,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'MH02EF9012',
      photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
      pricePerKm: 17.0,
      pricePerDay: 2300.0,
      pricePerHour: 210.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    },
    {
      id: 'car4',
      vendorId: 'v2',
      make: 'BMW',
      model: '3 Series',
      year: 2022,
      type: CarCategory.LUXURY,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'MH02GH3456',
      photos: ['https://images.unsplash.com/photo-1555215695-3004980ad54e'],
      pricePerKm: 40.0,
      pricePerDay: 9000.0,
      pricePerHour: 950.0,
      availableTripTypes: [TripType.OUTSTATION, TripType.SELF_DRIVE],
    },
    {
      id: 'car9',
      vendorId: 'v5',
      make: 'Maruti Suzuki',
      model: 'WagonR',
      year: 2021,
      type: CarCategory.HATCHBACK,
      fuelType: FuelType.CNG,
      seating: 5,
      isAC: true,
      registrationNumber: 'DL01JK7890',
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: 13.0,
      pricePerDay: 1600.0,
      pricePerHour: 130.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    },
    {
      id: 'car10',
      vendorId: 'v5',
      make: 'Toyota',
      model: 'Innova Crysta',
      year: 2022,
      type: CarCategory.SUV,
      fuelType: FuelType.DIESEL,
      seating: 7,
      isAC: true,
      registrationNumber: 'DL01LM1234',
      photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
      pricePerKm: 21.0,
      pricePerDay: 4000.0,
      pricePerHour: 350.0,
      availableTripTypes: [TripType.OUTSTATION, TripType.AIRPORT_TRANSFER],
    },
    {
      id: 'car17',
      vendorId: 'v9',
      make: 'Tata',
      model: 'Tiago',
      year: 2021,
      type: CarCategory.HATCHBACK,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'KA03NP5678',
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: 12.0,
      pricePerDay: 1500.0,
      pricePerHour: 120.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    },
    {
      id: 'car18',
      vendorId: 'v9',
      make: 'Mahindra',
      model: 'Thar',
      year: 2022,
      type: CarCategory.SUV,
      fuelType: FuelType.DIESEL,
      seating: 4,
      isAC: true,
      registrationNumber: 'KA03QR9012',
      photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
      pricePerKm: 18.0,
      pricePerDay: 3500.0,
      pricePerHour: 300.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.OUTSTATION],
    },
    {
      id: 'car25',
      vendorId: 'v13',
      make: 'Maruti Suzuki',
      model: 'Baleno',
      year: 2022,
      type: CarCategory.HATCHBACK,
      fuelType: FuelType.PETROL,
      seating: 5,
      isAC: true,
      registrationNumber: 'TN01ST3456',
      photos: ['https://images.unsplash.com/photo-1549399542-7e3f8b79c341'],
      pricePerKm: 12.0,
      pricePerDay: 1500.0,
      pricePerHour: 120.0,
      availableTripTypes: [TripType.SELF_DRIVE, TripType.LOCAL],
    },
    {
      id: 'car26',
      vendorId: 'v13',
      make: 'Toyota',
      model: 'Fortuner',
      year: 2022,
      type: CarCategory.SUV,
      fuelType: FuelType.DIESEL,
      seating: 7,
      isAC: true,
      registrationNumber: 'TN01UV7890',
      photos: ['https://images.unsplash.com/photo-1533473359331-0135ef1b58bf'],
      pricePerKm: 18.0,
      pricePerDay: 3500.0,
      pricePerHour: 300.0,
      availableTripTypes: [TripType.OUTSTATION, TripType.AIRPORT_TRANSFER],
    },
  ];

  for (const car of carsData) {
    await prisma.car.create({
      data: car,
    });
  }

  // 7. Create Commission Config Rules
  await prisma.commissionConfig.createMany({
    data: [
      {
        city: null, // Default
        carCategory: null,
        tripType: null,
        percentage: 10.0,
        effectiveFrom: new Date(),
      },
      {
        city: null,
        carCategory: CarCategory.LUXURY,
        tripType: null,
        percentage: 12.0,
        effectiveFrom: new Date(),
      },
      {
        city: null,
        carCategory: null,
        tripType: TripType.OUTSTATION,
        percentage: 8.0,
        effectiveFrom: new Date(),
      },
    ],
  });

  // 8. Create Banners
  await prisma.banner.createMany({
    data: [
      {
        title: 'Super Summer Sale',
        imageUrl: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341',
        ctaLink: 'https://drivego.in/offers/summer',
        displayOrder: 2,
        isActive: true,
      },
      {
        title: 'Explore Luxury Drives',
        imageUrl: 'https://images.unsplash.com/photo-1555215695-3004980ad54e',
        ctaLink: 'https://drivego.in/offers/luxury',
        displayOrder: 1,
        isActive: true,
      },
      {
        title: 'Expired Offer',
        imageUrl: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70',
        ctaLink: 'https://drivego.in/offers/expired',
        displayOrder: 0,
        isActive: false,
      },
      {
        title: 'Outstation Getaways',
        imageUrl: 'https://images.unsplash.com/photo-1502877338535-766e1452684a',
        ctaLink: 'https://drivego.in/offers/outstation',
        displayOrder: 3,
        isActive: true,
      },
    ],
  });

  console.log('Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

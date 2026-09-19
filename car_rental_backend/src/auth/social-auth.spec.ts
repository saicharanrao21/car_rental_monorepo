import { Test, TestingModule } from '@nestjs/testing';
import { SocialAuthService } from './social-auth.service';
import { SocialAuthController } from './social-auth.controller';
import { AuthService } from './auth.service';
import { PrismaService } from '../prisma/prisma.service';
import { BadRequestException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { Role } from '@prisma/client';

describe('SocialAuthService and SocialAuthController', () => {
  let service: SocialAuthService;
  let controller: SocialAuthController;
  let prisma: any;
  let authService: any;

  const mockUser = {
    id: 'user-google-1',
    name: 'Jane Doe',
    email: 'jane@example.com',
    phone: null,
    googleId: 'google-sub-12345',
    appleId: null,
    role: Role.CUSTOMER,
    profilePhotoUrl: 'https://lh3.googleusercontent.com/photo.jpg',
    banned: false,
    vendor: null,
  };

  const mockTokens = {
    accessToken: 'mock_jwt_access_token',
    refreshToken: 'mock_jwt_refresh_token',
  };

  beforeEach(async () => {
    prisma = {
      user: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
      },
    };

    authService = {
      issueTokens: jest.fn().mockResolvedValue(mockTokens),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [SocialAuthController],
      providers: [
        SocialAuthService,
        { provide: PrismaService, useValue: prisma },
        { provide: AuthService, useValue: authService },
      ],
    }).compile();

    service = module.get<SocialAuthService>(SocialAuthService);
    controller = module.get<SocialAuthController>(SocialAuthController);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
    expect(controller).toBeDefined();
  });

  describe('loginWithGoogle', () => {
    it('throws BadRequestException if idToken is omitted', async () => {
      await expect(service.loginWithGoogle('')).rejects.toThrow(BadRequestException);
    });

    it('creates a new customer record when googleId is first seen and no matching email exists', async () => {
      jest.spyOn(service, 'verifyGoogleToken').mockResolvedValue({
        googleId: 'google-sub-12345',
        email: 'jane@example.com',
        name: 'Jane Doe',
        picture: 'https://lh3.googleusercontent.com/photo.jpg',
      });

      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.findFirst.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue(mockUser);

      const result = await service.loginWithGoogle('valid_google_id_token');

      expect(result.isNewUser).toBe(true);
      expect(result.accessToken).toBe(mockTokens.accessToken);
      expect(result.refreshToken).toBe(mockTokens.refreshToken);
      expect(prisma.user.create).toHaveBeenCalledWith({
        data: {
          googleId: 'google-sub-12345',
          email: 'jane@example.com',
          name: 'Jane Doe',
          profilePhotoUrl: 'https://lh3.googleusercontent.com/photo.jpg',
          role: Role.CUSTOMER,
        },
        include: { vendor: true },
      });
      expect(authService.issueTokens).toHaveBeenCalledWith(mockUser.id, mockUser.role);
    });

    it('links googleId to existing user when email matches an existing account (e.g. created via phone OTP)', async () => {
      const existingPhoneUser = {
        id: 'user-phone-otp-existing',
        name: 'Jane Original',
        phone: '+919876543210',
        email: 'jane@example.com',
        googleId: null,
        appleId: null,
        role: Role.CUSTOMER,
        profilePhotoUrl: null,
        banned: false,
        vendor: null,
      };

      jest.spyOn(service, 'verifyGoogleToken').mockResolvedValue({
        googleId: 'google-sub-12345',
        email: 'jane@example.com',
        name: 'Jane Doe',
        picture: 'https://lh3.googleusercontent.com/photo.jpg',
      });

      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.findFirst.mockResolvedValue(existingPhoneUser);
      prisma.user.update.mockResolvedValue({
        ...existingPhoneUser,
        googleId: 'google-sub-12345',
        profilePhotoUrl: 'https://lh3.googleusercontent.com/photo.jpg',
      });

      const result = await service.loginWithGoogle('valid_google_id_token');

      expect(result.isNewUser).toBe(false);
      expect(result.linked).toBe(true);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: existingPhoneUser.id },
        data: {
          googleId: 'google-sub-12345',
          profilePhotoUrl: 'https://lh3.googleusercontent.com/photo.jpg',
        },
        include: { vendor: true },
      });
    });

    it('logs in directly when user is already known by googleId', async () => {
      jest.spyOn(service, 'verifyGoogleToken').mockResolvedValue({
        googleId: 'google-sub-12345',
        email: 'jane@example.com',
        name: 'Jane Doe',
      });

      prisma.user.findUnique.mockResolvedValue(mockUser);

      const result = await service.loginWithGoogle('valid_google_id_token');

      expect(result.isNewUser).toBe(false);
      expect(prisma.user.create).not.toHaveBeenCalled();
      expect(prisma.user.update).not.toHaveBeenCalled();
      expect(authService.issueTokens).toHaveBeenCalledWith(mockUser.id, mockUser.role);
    });

    it('rejects banned user with ForbiddenException', async () => {
      jest.spyOn(service, 'verifyGoogleToken').mockResolvedValue({
        googleId: 'google-banned',
        email: 'banned@example.com',
      });

      prisma.user.findUnique.mockResolvedValue({ ...mockUser, banned: true });

      await expect(service.loginWithGoogle('banned_token')).rejects.toThrow(ForbiddenException);
    });

    it('throws UnauthorizedException if token verification fails', async () => {
      jest.spyOn(service, 'verifyGoogleToken').mockRejectedValue(
        new UnauthorizedException('Google token verification failed: Token expired'),
      );

      await expect(service.loginWithGoogle('expired_token')).rejects.toThrow(UnauthorizedException);
    });
  });

  describe('loginWithApple', () => {
    it('throws BadRequestException if identityToken is omitted', async () => {
      await expect(service.loginWithApple('')).rejects.toThrow(BadRequestException);
    });

    it('creates a new customer record when appleId is first seen and no matching email exists', async () => {
      jest.spyOn(service, 'verifyAppleToken').mockResolvedValue({
        appleId: 'apple-sub-67890',
        email: 'appleuser@privaterelay.appleid.com',
      });

      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.findFirst.mockResolvedValue(null);
      prisma.user.create.mockResolvedValue({
        ...mockUser,
        id: 'user-apple-1',
        appleId: 'apple-sub-67890',
        googleId: null,
      });

      const result = await service.loginWithApple('valid_apple_identity_token', 'Apple User');

      expect(result.isNewUser).toBe(true);
      expect(prisma.user.create).toHaveBeenCalledWith({
        data: {
          appleId: 'apple-sub-67890',
          email: 'appleuser@privaterelay.appleid.com',
          name: 'Apple User',
          role: Role.CUSTOMER,
        },
        include: { vendor: true },
      });
    });

    it('links appleId to existing user when email matches', async () => {
      const existingUser = {
        id: 'user-existing-1',
        name: 'Existing User',
        email: 'user@example.com',
        banned: false,
        role: Role.CUSTOMER,
      };

      jest.spyOn(service, 'verifyAppleToken').mockResolvedValue({
        appleId: 'apple-sub-67890',
        email: 'user@example.com',
      });

      prisma.user.findUnique.mockResolvedValue(null);
      prisma.user.findFirst.mockResolvedValue(existingUser);
      prisma.user.update.mockResolvedValue({
        ...existingUser,
        appleId: 'apple-sub-67890',
      });

      const result = await service.loginWithApple('valid_apple_identity_token');

      expect(result.linked).toBe(true);
      expect(prisma.user.update).toHaveBeenCalledWith({
        where: { id: existingUser.id },
        data: { appleId: 'apple-sub-67890' },
        include: { vendor: true },
      });
    });
  });

  describe('SocialAuthController', () => {
    it('POST /auth/social/google calls service.loginWithGoogle', async () => {
      jest.spyOn(service, 'loginWithGoogle').mockResolvedValue({
        user: mockUser,
        isNewUser: false,
        ...mockTokens,
      } as any);

      const res = await controller.loginWithGoogle({ idToken: 'token-123' });
      expect(res.user).toEqual(mockUser);
      expect(service.loginWithGoogle).toHaveBeenCalledWith('token-123');
    });

    it('POST /auth/social/apple calls service.loginWithApple', async () => {
      jest.spyOn(service, 'loginWithApple').mockResolvedValue({
        user: mockUser,
        isNewUser: false,
        ...mockTokens,
      } as any);

      const res = await controller.loginWithApple({
        identityToken: 'token-apple-123',
        fullName: 'Apple Customer',
      });
      expect(res.user).toEqual(mockUser);
      expect(service.loginWithApple).toHaveBeenCalledWith('token-apple-123', 'Apple Customer');
    });
  });
});

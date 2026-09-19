import {
  Injectable,
  UnauthorizedException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';
import { Role } from '@prisma/client';
import { OAuth2Client } from 'google-auth-library';
import appleSignin from 'apple-signin-auth';

@Injectable()
export class SocialAuthService {
  private googleClient: OAuth2Client;

  constructor(
    private readonly prisma: PrismaService,
    private readonly authService: AuthService,
  ) {
    this.googleClient = new OAuth2Client();
  }

  async verifyGoogleToken(idToken: string): Promise<{
    googleId: string;
    email: string;
    name?: string;
    picture?: string;
  }> {
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
      });
      const payload = ticket.getPayload();
      if (!payload || !payload.sub) {
        throw new UnauthorizedException('Invalid Google ID token payload');
      }
      return {
        googleId: payload.sub,
        email: payload.email || '',
        name: payload.name,
        picture: payload.picture,
      };
    } catch (err: any) {
      throw new UnauthorizedException(
        `Google token verification failed: ${err.message}`,
      );
    }
  }

  async verifyAppleToken(identityToken: string): Promise<{
    appleId: string;
    email?: string;
  }> {
    try {
      const applePayload = await appleSignin.verifyIdToken(identityToken, {
        ignoreExpiration: false,
      });
      if (!applePayload || !applePayload.sub) {
        throw new UnauthorizedException('Invalid Apple identity token payload');
      }
      return {
        appleId: applePayload.sub,
        email: applePayload.email,
      };
    } catch (err: any) {
      throw new UnauthorizedException(
        `Apple token verification failed: ${err.message}`,
      );
    }
  }

  async loginWithGoogle(idToken: string) {
    if (!idToken) {
      throw new BadRequestException('idToken is required');
    }

    const { googleId, email, name, picture } =
      await this.verifyGoogleToken(idToken);

    // 1. Look for user by googleId
    let user = await this.prisma.user.findUnique({
      where: { googleId },
      include: { vendor: true },
    });

    if (user) {
      if (user.banned) {
        throw new ForbiddenException('This user account has been banned.');
      }
      const tokens = await this.authService.issueTokens(user.id, user.role);
      return { user, ...tokens, isNewUser: false };
    }

    // 2. If email exists, check for existing user to link
    if (email) {
      const existingUserByEmail = await this.prisma.user.findFirst({
        where: { email },
        include: { vendor: true },
      });

      if (existingUserByEmail) {
        if (existingUserByEmail.banned) {
          throw new ForbiddenException('This user account has been banned.');
        }
        user = await this.prisma.user.update({
          where: { id: existingUserByEmail.id },
          data: {
            googleId,
            profilePhotoUrl:
              existingUserByEmail.profilePhotoUrl || picture || null,
          },
          include: { vendor: true },
        });
        const tokens = await this.authService.issueTokens(user.id, user.role);
        return { user, ...tokens, isNewUser: false, linked: true };
      }
    }

    // 3. Otherwise create new customer user
    user = await this.prisma.user.create({
      data: {
        googleId,
        email: email || null,
        name: name || 'Google User',
        profilePhotoUrl: picture || null,
        role: Role.CUSTOMER,
      },
      include: { vendor: true },
    });

    const tokens = await this.authService.issueTokens(user.id, user.role);
    return { user, ...tokens, isNewUser: true };
  }

  async loginWithApple(identityToken: string, fullName?: string) {
    if (!identityToken) {
      throw new BadRequestException('identityToken is required');
    }

    const { appleId, email } = await this.verifyAppleToken(identityToken);

    // 1. Look for user by appleId
    let user = await this.prisma.user.findUnique({
      where: { appleId },
      include: { vendor: true },
    });

    if (user) {
      if (user.banned) {
        throw new ForbiddenException('This user account has been banned.');
      }
      const tokens = await this.authService.issueTokens(user.id, user.role);
      return { user, ...tokens, isNewUser: false };
    }

    // 2. If email exists, check for existing user to link
    if (email) {
      const existingUserByEmail = await this.prisma.user.findFirst({
        where: { email },
        include: { vendor: true },
      });

      if (existingUserByEmail) {
        if (existingUserByEmail.banned) {
          throw new ForbiddenException('This user account has been banned.');
        }
        user = await this.prisma.user.update({
          where: { id: existingUserByEmail.id },
          data: { appleId },
          include: { vendor: true },
        });
        const tokens = await this.authService.issueTokens(user.id, user.role);
        return { user, ...tokens, isNewUser: false, linked: true };
      }
    }

    // 3. Otherwise create new customer user
    user = await this.prisma.user.create({
      data: {
        appleId,
        email: email || null,
        name: fullName || 'Apple User',
        role: Role.CUSTOMER,
      },
      include: { vendor: true },
    });

    const tokens = await this.authService.issueTokens(user.id, user.role);
    return { user, ...tokens, isNewUser: true };
  }
}

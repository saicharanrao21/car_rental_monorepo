import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    const nodeEnv = configService.get<string>('NODE_ENV');
    const accessSecret = configService.get<string>('JWT_ACCESS_SECRET');
    if (
      nodeEnv === 'production' &&
      (!accessSecret || accessSecret.includes('change_me') || accessSecret.length < 32)
    ) {
      throw new Error(
        'CRITICAL SECURITY CONFIGURATION ERROR: JWT_ACCESS_SECRET must be securely configured in production (minimum 32 characters) for JwtStrategy.',
      );
    }

    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: accessSecret || 'dev_access_secret_key_change_me_12345!',
    });
  }

  async validate(payload: any) {
    // This value is returned and attached to req.user
    return { userId: payload.userId, id: payload.userId, role: payload.role };
  }
}

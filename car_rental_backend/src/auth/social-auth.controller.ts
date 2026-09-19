import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { SocialAuthService } from './social-auth.service';

export class GoogleLoginDto {
  idToken!: string;
}

export class AppleLoginDto {
  identityToken!: string;
  fullName?: string;
}

@Controller('auth/social')
export class SocialAuthController {
  constructor(private readonly socialAuthService: SocialAuthService) {}

  @Post('google')
  @HttpCode(HttpStatus.OK)
  async loginWithGoogle(@Body() body: GoogleLoginDto) {
    return this.socialAuthService.loginWithGoogle(body.idToken);
  }

  @Post('apple')
  @HttpCode(HttpStatus.OK)
  async loginWithApple(@Body() body: AppleLoginDto) {
    return this.socialAuthService.loginWithApple(body.identityToken, body.fullName);
  }
}

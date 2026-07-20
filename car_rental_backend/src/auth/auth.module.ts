import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import { SmsProviderService, MockSmsProvider } from './sms-provider.service';
import { JwtStrategy } from './strategies/jwt.strategy';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.register({}),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    {
      provide: SmsProviderService,
      useClass: MockSmsProvider,
    },
    JwtStrategy,
  ],
  exports: [
    AuthService,
    OtpService,
    SmsProviderService,
    JwtStrategy,
    PassportModule,
  ],
})
export class AuthModule {}

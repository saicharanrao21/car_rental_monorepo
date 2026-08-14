import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { OtpService } from './otp.service';
import {
  SmsProviderService,
  MockSmsProvider,
  Msg91SmsProvider,
} from './sms-provider.service';
import { JwtStrategy } from './strategies/jwt.strategy';

import { CommonModule } from '../common/common.module';

@Module({
  imports: [
    PassportModule.register({ defaultStrategy: 'jwt' }),
    JwtModule.register({}),
    CommonModule,
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    OtpService,
    {
      provide: SmsProviderService,
      useFactory: (configService: ConfigService) => {
        const nodeEnv = configService.get<string>('NODE_ENV');
        const smsProvider = configService.get<string>('SMS_PROVIDER');

        if (nodeEnv === 'production' || smsProvider === 'msg91') {
          return new Msg91SmsProvider(configService);
        }

        return new MockSmsProvider();
      },
      inject: [ConfigService],
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

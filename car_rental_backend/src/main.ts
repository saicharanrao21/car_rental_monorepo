import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { ExcludePasswordHashInterceptor } from './common/exclude-password-hash.interceptor';
import { json, urlencoded } from 'express';
import { Prisma } from '@prisma/client';

import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';

Prisma.Decimal.prototype.toJSON = function () {
  return this.toNumber();
};

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });
  const configService = app.get(ConfigService);

  // Security Headers via Helmet
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      contentSecurityPolicy: false, // CSP managed at reverse-proxy / web app level
    }),
  );

  // Custom body parser middleware to capture rawBody for webhook verification
  app.use(
    json({
      verify: (req: any, res, buf) => {
        if (buf && buf.length) {
          req.rawBody = buf.toString('utf8');
        }
      },
    }),
  );
  app.use(urlencoded({ extended: true }));

  // Environment-driven CORS configuration
  const rawCors = configService.get<string>('CORS_ALLOWED_ORIGINS');
  const allowedOrigins: string[] = rawCors
    ? rawCors
        .split(',')
        .map((origin) => origin.trim())
        .filter(Boolean)
    : [
        'http://localhost:8080',
        'http://localhost:8085',
        'http://localhost:3000',
        'http://127.0.0.1:8080',
        'http://127.0.0.1:8085',
        'http://127.0.0.1:3000',
      ];

  app.enableCors({
    origin: allowedOrigins,
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalInterceptors(new ExcludePasswordHashInterceptor());

  await app.listen(process.env.PORT || 3000, '0.0.0.0');
}
bootstrap();

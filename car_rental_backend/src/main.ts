import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { ExcludePasswordHashInterceptor } from './common/exclude-password-hash.interceptor';
import { json, urlencoded } from 'express';
import { Prisma } from '@prisma/client';

Prisma.Decimal.prototype.toJSON = function () {
  return this.toNumber();
};

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bodyParser: false });

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
  app.enableCors({
    origin: [
      'http://localhost:8080', // admin_panel local dev
      'http://localhost:3000', // local dev tooling
      // TODO: Add production admin_panel web domain once deployed
    ],
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

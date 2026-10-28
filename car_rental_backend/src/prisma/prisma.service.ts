import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  async onModuleInit() {
    try {
      await this.$connect();
    } catch (error) {
      console.error(
        '[PrismaService] Database connection initialization failed:',
        error instanceof Error ? error.message : error,
      );
      if (
        process.env.NODE_ENV === 'production' &&
        process.env.STRICT_DB_INIT === 'true'
      ) {
        throw error;
      }
    }
  }

  async onModuleDestroy() {
    await this.$disconnect();
  }
}

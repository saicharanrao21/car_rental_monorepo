import { Injectable, NestMiddleware } from '@nestjs/common';
import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';

export interface RequestWithCorrelation extends Request {
  correlationId?: string;
}

const SAFE_CORRELATION_ID_REGEX = /^[a-zA-Z0-9_-]{1,64}$/;

@Injectable()
export class CorrelationIdMiddleware implements NestMiddleware {
  use(req: RequestWithCorrelation, res: Response, next: NextFunction) {
    const rawHeader =
      (req.headers['x-request-id'] as string) ||
      (req.headers['x-correlation-id'] as string);

    let correlationId: string;

    if (
      typeof rawHeader === 'string' &&
      rawHeader.trim().length > 0 &&
      rawHeader.trim().length <= 64 &&
      SAFE_CORRELATION_ID_REGEX.test(rawHeader.trim())
    ) {
      correlationId = rawHeader.trim();
    } else {
      correlationId = randomUUID();
    }

    req.correlationId = correlationId;
    res.setHeader('X-Request-ID', correlationId);

    next();
  }
}

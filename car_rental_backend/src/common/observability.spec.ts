import { CorrelationIdMiddleware } from './correlation-id.middleware';
import { StructuredLoggerService } from './structured-logger.service';

describe('Phase 5: Observability & Correlation ID Infrastructure', () => {
  describe('CorrelationIdMiddleware Hardening (SEC-P2-02)', () => {
    let middleware: CorrelationIdMiddleware;

    beforeEach(() => {
      middleware = new CorrelationIdMiddleware();
    });

    it('generates a new UUIDv4 correlation ID if header is missing', () => {
      const req: any = { headers: {} };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).toBeDefined();
      expect(typeof req.correlationId).toBe('string');
      expect(req.correlationId.length).toBe(36); // UUID length
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', req.correlationId);
      expect(nextMock).toHaveBeenCalled();
    });

    it('generates a new UUIDv4 if header is empty or only whitespace', () => {
      const req: any = { headers: { 'x-request-id': '   ' } };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).toBeDefined();
      expect(req.correlationId.length).toBe(36);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', req.correlationId);
      expect(nextMock).toHaveBeenCalled();
    });

    it('preserves valid safe request IDs (alphanumeric, dashes, underscores up to 64 chars)', () => {
      const safeId = 'req-trace_custom-98765-ABC';
      const req: any = { headers: { 'x-request-id': safeId } };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).toBe(safeId);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', safeId);
      expect(nextMock).toHaveBeenCalled();
    });

    it('replaces oversized request IDs (>64 chars) with a safe UUIDv4', () => {
      const oversizedId = 'a'.repeat(65);
      const req: any = { headers: { 'x-request-id': oversizedId } };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).not.toBe(oversizedId);
      expect(req.correlationId.length).toBe(36);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', req.correlationId);
    });

    it('replaces CRLF injection attempts with a safe UUIDv4', () => {
      const crlfId = 'req-123\r\nInjected-Header: evil-payload';
      const req: any = { headers: { 'x-request-id': crlfId } };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).not.toBe(crlfId);
      expect(req.correlationId).not.toContain('\r');
      expect(req.correlationId).not.toContain('\n');
      expect(req.correlationId.length).toBe(36);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', req.correlationId);
    });

    it('replaces special characters and spaces with a safe UUIDv4', () => {
      const dirtyId = 'req<script>alert(1)</script>';
      const req: any = { headers: { 'x-request-id': dirtyId } };
      const setHeaderMock = jest.fn();
      const res: any = { setHeader: setHeaderMock };
      const nextMock = jest.fn();

      middleware.use(req, res, nextMock);

      expect(req.correlationId).not.toBe(dirtyId);
      expect(req.correlationId.length).toBe(36);
      expect(setHeaderMock).toHaveBeenCalledWith('X-Request-ID', req.correlationId);
    });
  });

  describe('StructuredLoggerService Redaction', () => {
    let logger: StructuredLoggerService;

    beforeEach(() => {
      logger = new StructuredLoggerService();
    });

    it('redacts sensitive Bearer tokens from log output', () => {
      const spy = jest.spyOn(console, 'log').mockImplementation(() => {});
      logger.log('Incoming request with Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.doNotLeakThisToken');

      expect(spy).toHaveBeenCalled();
      const loggedOutput = spy.mock.calls[0][0];
      expect(loggedOutput).toContain('Bearer [REDACTED]');
      expect(loggedOutput).not.toContain('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9');
      spy.mockRestore();
    });

    it('redacts 6-digit OTP codes and passwords', () => {
      const spy = jest.spyOn(console, 'log').mockImplementation(() => {});
      logger.log('OTP dispatch event otp: "123456" password: "mySecretPassword123"');

      expect(spy).toHaveBeenCalled();
      const loggedOutput = spy.mock.calls[0][0];
      expect(loggedOutput).not.toContain('123456');
      expect(loggedOutput).not.toContain('mySecretPassword123');
      expect(loggedOutput).toContain('[REDACTED]');
      spy.mockRestore();
    });
  });
});

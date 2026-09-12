import { ConfigService } from '@nestjs/config';
import { ServiceUnavailableException } from '@nestjs/common';
import { GoogleGeminiAdapter } from '../adapters/ai/google-gemini.adapter';

describe('GoogleGeminiAdapter - Embed Method & Production Safety', () => {
  let originalEnv: string | undefined;

  beforeEach(() => {
    originalEnv = process.env.NODE_ENV;
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
    jest.restoreAllMocks();
  });

  it('in production without API key, embed() throws ServiceUnavailableException loudly rather than returning fake vectors', async () => {
    process.env.NODE_ENV = 'production';

    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'GEMINI_API_KEY') return '';
        return '';
      }),
    } as unknown as ConfigService;

    const adapter = new GoogleGeminiAdapter(configService);

    await expect(
      adapter.embed({
        texts: ['DriveGo luxury car rental', 'Affordable vehicle hire'],
      }),
    ).rejects.toThrow(ServiceUnavailableException);
  });

  it('with GEMINI_API_KEY configured, embed() calls the text-embedding-004 API endpoint and returns real vectors', async () => {
    process.env.NODE_ENV = 'production';

    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'GEMINI_API_KEY') return 'test_gemini_api_key_12345';
        return '';
      }),
    } as unknown as ConfigService;

    const adapter = new GoogleGeminiAdapter(configService);

    const mockEmbeddings = [
      { values: [0.1234, -0.5678, 0.9012] },
      { values: [0.4321, 0.8765, -0.2109] },
    ];

    const mockFetch = jest.spyOn(global, 'fetch' as any).mockResolvedValueOnce({
      ok: true,
      status: 200,
      json: async () => ({ embeddings: mockEmbeddings }),
    } as any);

    const result = await adapter.embed({
      texts: ['Car rental Bangalore', 'Self drive SUV'],
    });

    expect(mockFetch).toHaveBeenCalledTimes(1);
    const [callUrl, callOptions] = mockFetch.mock.calls[0];
    expect(callUrl).toContain('text-embedding-004:batchEmbedContents?key=test_gemini_api_key_12345');
    expect(result.embeddings).toEqual([
      [0.1234, -0.5678, 0.9012],
      [0.4321, 0.8765, -0.2109],
    ]);
    expect(result.modelUsed).toBe('text-embedding-004');
    expect(result.provider).toBe('gemini');
  });

  it('with GEMINI_API_KEY configured, propagates API failure as ServiceUnavailableException in production', async () => {
    process.env.NODE_ENV = 'production';

    const configService = {
      get: jest.fn((key: string) => {
        if (key === 'GEMINI_API_KEY') return 'test_gemini_api_key_invalid';
        return '';
      }),
    } as unknown as ConfigService;

    const adapter = new GoogleGeminiAdapter(configService);

    jest.spyOn(global, 'fetch' as any).mockResolvedValueOnce({
      ok: false,
      status: 403,
      text: async () => 'API key expired or quota exceeded',
    } as any);

    await expect(
      adapter.embed({
        texts: ['Sample prompt text'],
      }),
    ).rejects.toThrow(ServiceUnavailableException);
  });
});

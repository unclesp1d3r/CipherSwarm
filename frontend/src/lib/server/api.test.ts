import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import axios from 'axios';
import { z } from 'zod';
import { error } from '@sveltejs/kit';
import {
    ServerApiClient,
    serverApi,
    createAuthenticatedServerApi,
    createSessionServerApi,
    ApiErrorSchema,
    PaginatedResponseSchema,
    SuccessResponseSchema
} from './api';

// Mock axios
vi.mock('axios', () => ({
    default: {
        create: vi.fn(() => ({
            get: vi.fn(),
            post: vi.fn(),
            put: vi.fn(),
            patch: vi.fn(),
            delete: vi.fn(),
            defaults: {
                headers: {
                    common: {}
                }
            },
            interceptors: {
                request: {
                    use: vi.fn()
                },
                response: {
                    use: vi.fn()
                }
            }
        })),
        isAxiosError: vi.fn()
    }
}));

// Mock SvelteKit error
vi.mock('@sveltejs/kit', () => ({
    error: vi.fn()
}));

// Mock config
vi.mock('$lib/config', () => ({
    config: {
        apiBaseUrl: 'http://localhost:8000'
    }
}));

// Type for mock axios instance
type MockAxiosInstance = {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    put: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
    defaults: {
        headers: {
            common: Record<string, string>;
        };
    };
    interceptors: {
        request: {
            use: ReturnType<typeof vi.fn>;
        };
        response: {
            use: ReturnType<typeof vi.fn>;
        };
    };
};

describe('ServerApiClient', () => {
    let client: ServerApiClient;
    let mockAxiosInstance: MockAxiosInstance;

    beforeEach(() => {
        vi.clearAllMocks();
        mockAxiosInstance = {
            get: vi.fn(),
            post: vi.fn(),
            put: vi.fn(),
            patch: vi.fn(),
            delete: vi.fn(),
            defaults: {
                headers: {
                    common: {}
                }
            },
            interceptors: {
                request: {
                    use: vi.fn()
                },
                response: {
                    use: vi.fn()
                }
            }
        };
        (axios.create as ReturnType<typeof vi.fn>).mockReturnValue(mockAxiosInstance);
        client = new ServerApiClient();
    });

    afterEach(() => {
        vi.restoreAllMocks();
    });

    describe('constructor', () => {
        it('should create axios instance with default config', () => {
            expect(axios.create).toHaveBeenCalledWith({
                baseURL: 'http://localhost:8000',
                timeout: 30000,
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json'
                }
            });
        });

        it('should create axios instance with custom baseURL', () => {
            const customUrl = 'http://custom.example.com';
            new ServerApiClient(customUrl);

            expect(axios.create).toHaveBeenCalledWith({
                baseURL: customUrl,
                timeout: 30000,
                headers: {
                    'Content-Type': 'application/json',
                    Accept: 'application/json'
                }
            });
        });

        it('should set up request and response interceptors', () => {
            expect(mockAxiosInstance.interceptors.request.use).toHaveBeenCalled();
            expect(mockAxiosInstance.interceptors.response.use).toHaveBeenCalled();
        });
    });

    describe('authentication methods', () => {
        it('should set authorization header', () => {
            const token = 'test-token';
            client.setAuth(token);

            expect(mockAxiosInstance.defaults.headers.common['Authorization']).toBe(
                `Bearer ${token}`
            );
        });

        it('should set cookie header', () => {
            const cookie = 'sessionid=abc123';
            client.setSessionCookie(cookie);

            expect(mockAxiosInstance.defaults.headers.common['Cookie']).toBe(cookie);
        });
    });

    describe('GET requests', () => {
        const testSchema = z.object({
            id: z.number(),
            name: z.string()
        });

        it('should make successful GET request with validation', async () => {
            const mockData = { id: 1, name: 'test' };
            mockAxiosInstance.get.mockResolvedValue({ data: mockData });

            const result = await client.get('/test', testSchema);

            expect(mockAxiosInstance.get).toHaveBeenCalledWith('/test', undefined);
            expect(result).toEqual(mockData);
        });

        it('should make GET request with config', async () => {
            const mockData = { id: 1, name: 'test' };
            const config = { params: { page: 1 } };
            mockAxiosInstance.get.mockResolvedValue({ data: mockData });

            await client.get('/test', testSchema, config);

            expect(mockAxiosInstance.get).toHaveBeenCalledWith('/test', config);
        });

        it('should handle validation errors', async () => {
            const invalidData = { id: 'invalid', name: 123 };
            mockAxiosInstance.get.mockResolvedValue({ data: invalidData });

            await expect(client.get('/test', testSchema)).rejects.toThrow();
        });

        it('should make raw GET request', async () => {
            const mockResponse = { data: { test: 'data' }, status: 200 };
            mockAxiosInstance.get.mockResolvedValue(mockResponse);

            const result = await client.getRaw('/test');

            expect(mockAxiosInstance.get).toHaveBeenCalledWith('/test', undefined);
            expect(result).toEqual(mockResponse);
        });
    });

    describe('POST requests', () => {
        const testSchema = z.object({
            id: z.number(),
            message: z.string()
        });

        it('should make successful POST request with validation', async () => {
            const mockData = { id: 1, message: 'created' };
            const postData = { name: 'test' };
            mockAxiosInstance.post.mockResolvedValue({ data: mockData });

            const result = await client.post('/test', postData, testSchema);

            expect(mockAxiosInstance.post).toHaveBeenCalledWith('/test', postData, undefined);
            expect(result).toEqual(mockData);
        });

        it('should make raw POST request', async () => {
            const mockResponse = { data: { test: 'data' }, status: 201 };
            const postData = { name: 'test' };
            mockAxiosInstance.post.mockResolvedValue(mockResponse);

            const result = await client.postRaw('/test', postData);

            expect(mockAxiosInstance.post).toHaveBeenCalledWith('/test', postData, undefined);
            expect(result).toEqual(mockResponse);
        });
    });

    describe('PUT requests', () => {
        const testSchema = z.object({
            id: z.number(),
            message: z.string()
        });

        it('should make successful PUT request with validation', async () => {
            const mockData = { id: 1, message: 'updated' };
            const putData = { name: 'test' };
            mockAxiosInstance.put.mockResolvedValue({ data: mockData });

            const result = await client.put('/test', putData, testSchema);

            expect(mockAxiosInstance.put).toHaveBeenCalledWith('/test', putData, undefined);
            expect(result).toEqual(mockData);
        });

        it('should make raw PUT request', async () => {
            const mockResponse = { data: { test: 'data' }, status: 200 };
            const putData = { name: 'test' };
            mockAxiosInstance.put.mockResolvedValue(mockResponse);

            const result = await client.putRaw('/test', putData);

            expect(mockAxiosInstance.put).toHaveBeenCalledWith('/test', putData, undefined);
            expect(result).toEqual(mockResponse);
        });
    });

    describe('PATCH requests', () => {
        const testSchema = z.object({
            id: z.number(),
            message: z.string()
        });

        it('should make successful PATCH request with validation', async () => {
            const mockData = { id: 1, message: 'patched' };
            const patchData = { name: 'test' };
            mockAxiosInstance.patch.mockResolvedValue({ data: mockData });

            const result = await client.patch('/test', patchData, testSchema);

            expect(mockAxiosInstance.patch).toHaveBeenCalledWith('/test', patchData, undefined);
            expect(result).toEqual(mockData);
        });

        it('should make raw PATCH request', async () => {
            const mockResponse = { data: { test: 'data' }, status: 200 };
            const patchData = { name: 'test' };
            mockAxiosInstance.patch.mockResolvedValue(mockResponse);

            const result = await client.patchRaw('/test', patchData);

            expect(mockAxiosInstance.patch).toHaveBeenCalledWith('/test', patchData, undefined);
            expect(result).toEqual(mockResponse);
        });
    });

    describe('DELETE requests', () => {
        const testSchema = z.object({
            message: z.string()
        });

        it('should make successful DELETE request with validation', async () => {
            const mockData = { message: 'deleted' };
            mockAxiosInstance.delete.mockResolvedValue({ data: mockData });

            const result = await client.delete('/test', testSchema);

            expect(mockAxiosInstance.delete).toHaveBeenCalledWith('/test', undefined);
            expect(result).toEqual(mockData);
        });

        it('should make raw DELETE request', async () => {
            const mockResponse = { data: { test: 'data' }, status: 200 };
            mockAxiosInstance.delete.mockResolvedValue(mockResponse);

            const result = await client.deleteRaw('/test');

            expect(mockAxiosInstance.delete).toHaveBeenCalledWith('/test', undefined);
            expect(result).toEqual(mockResponse);
        });
    });

    describe('error handling', () => {
        const testSchema = z.object({ id: z.number() });

        it('should handle axios errors', async () => {
            const axiosError = {
                response: {
                    status: 404,
                    data: { detail: 'Not found' }
                },
                message: 'Request failed'
            };

            mockAxiosInstance.get.mockRejectedValue(axiosError);
            (axios.isAxiosError as unknown as ReturnType<typeof vi.fn>).mockReturnValue(true);
            (error as unknown as ReturnType<typeof vi.fn>).mockImplementation(
                (status: number, message: string) => {
                    throw new Error(`${status}: ${message}`);
                }
            );

            await expect(client.get('/test', testSchema)).rejects.toThrow('404: Not found');
            expect(error).toHaveBeenCalledWith(404, 'Not found');
        });

        it('should handle non-axios errors', async () => {
            const genericError = new Error('Generic error');

            mockAxiosInstance.get.mockRejectedValue(genericError);
            (axios.isAxiosError as unknown as ReturnType<typeof vi.fn>).mockReturnValue(false);
            (error as unknown as ReturnType<typeof vi.fn>).mockImplementation(
                (status: number, message: string) => {
                    throw new Error(`${status}: ${message}`);
                }
            );

            await expect(client.get('/test', testSchema)).rejects.toThrow(
                '500: Internal server error'
            );
            expect(error).toHaveBeenCalledWith(500, 'Internal server error');
        });

        it('should handle axios errors without response', async () => {
            const axiosError = {
                message: 'Network error'
            };

            mockAxiosInstance.get.mockRejectedValue(axiosError);
            (axios.isAxiosError as unknown as ReturnType<typeof vi.fn>).mockReturnValue(true);
            (error as unknown as ReturnType<typeof vi.fn>).mockImplementation(
                (status: number, message: string) => {
                    throw new Error(`${status}: ${message}`);
                }
            );

            await expect(client.get('/test', testSchema)).rejects.toThrow('500: Network error');
            expect(error).toHaveBeenCalledWith(500, 'Network error');
        });
    });
});

describe('Factory functions', () => {
    beforeEach(() => {
        vi.clearAllMocks();
        const mockAxiosInstance = {
            defaults: {
                headers: {
                    common: {}
                }
            },
            interceptors: {
                request: { use: vi.fn() },
                response: { use: vi.fn() }
            }
        };
        (axios.create as unknown as ReturnType<typeof vi.fn>).mockReturnValue(mockAxiosInstance);
    });

    it('should create authenticated server API', () => {
        const token = 'test-token';
        const client = createAuthenticatedServerApi(token);

        expect(client).toBeInstanceOf(ServerApiClient);
    });

    it('should create session server API', () => {
        const cookie = 'sessionid=abc123';
        const client = createSessionServerApi(cookie);

        expect(client).toBeInstanceOf(ServerApiClient);
    });

    it('should export default server API instance', () => {
        expect(serverApi).toBeInstanceOf(ServerApiClient);
    });
});

describe('Zod schemas', () => {
    describe('ApiErrorSchema', () => {
        it('should validate string error', () => {
            const error = { detail: 'Error message' };
            expect(ApiErrorSchema.parse(error)).toEqual(error);
        });

        it('should validate array error', () => {
            const error = {
                detail: [{ msg: 'Field required', loc: ['field'], type: 'missing' }]
            };
            expect(ApiErrorSchema.parse(error)).toEqual(error);
        });
    });

    describe('PaginatedResponseSchema', () => {
        it('should validate paginated response', () => {
            const itemSchema = z.object({ id: z.number() });
            const schema = PaginatedResponseSchema(itemSchema);

            const response = {
                items: [{ id: 1 }, { id: 2 }],
                total: 2,
                page: 1,
                per_page: 10,
                pages: 1
            };

            expect(schema.parse(response)).toEqual(response);
        });
    });

    describe('SuccessResponseSchema', () => {
        it('should validate success response', () => {
            const response = { message: 'Success', success: true };
            expect(SuccessResponseSchema.parse(response)).toEqual(response);
        });

        it('should validate success response without success field', () => {
            const response = { message: 'Success' };
            expect(SuccessResponseSchema.parse(response)).toEqual(response);
        });
    });
});

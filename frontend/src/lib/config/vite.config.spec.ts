import { describe, it, expect, vi } from 'vitest';

// Mock SvelteKit modules for Vite configuration tests
vi.mock('$app/environment', () => ({
    browser: false,
}));

vi.mock('$env/dynamic/private', () => ({
    env: {},
}));

vi.mock('$env/dynamic/public', () => ({
    env: {
        PUBLIC_API_BASE_URL: undefined,
    },
}));

describe('Vite Configuration', () => {
    it('should define API_BASE_URL constant for the application', () => {
        // The __API_BASE_URL__ constant should be defined by Vite
        expect(typeof __API_BASE_URL__).toBe('string');
    });

    it('should have a valid API base URL format', () => {
        // Ensure the API base URL is a valid URL format
        expect(__API_BASE_URL__).toMatch(/^https?:\/\/[^\s/$.?#].[^\s]*$/);
    });

    it('should use localhost for test environment', () => {
        // In test environment, should default to localhost
        expect(__API_BASE_URL__).toContain('localhost');
    });

    it('should contain port 8000 for backend API', () => {
        // The default backend port should be 8000
        expect(__API_BASE_URL__).toContain(':8000');
    });

    it('should integrate with new configuration system', async () => {
        // Test that the new config system works alongside Vite constants
        const { config, getApiBaseUrl } = await import('./index');

        expect(config).toBeDefined();
        expect(typeof getApiBaseUrl()).toBe('string');
        expect(getApiBaseUrl()).toMatch(/^https?:\/\/[^\s/$.?#].[^\s]*$/);
    });
});

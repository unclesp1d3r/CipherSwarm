// eslint-disable-next-line
import '@testing-library/jest-dom/vitest';
import { vi } from 'vitest';

// required for svelte5 + jsdom as jsdom does not support matchMedia
Object.defineProperty(window, 'matchMedia', {
    writable: true,
    enumerable: true,
    value: vi.fn().mockImplementation((query) => ({
        matches: false,
        media: query,
        onchange: null,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
        dispatchEvent: vi.fn(),
    })),
});

// Mock SvelteKit's payload for the client runtime
global.__SVELTEKIT_PAYLOAD__ = {
    data: {}, // Empty data object to prevent undefined errors
    status: 200,
    error: null,
    form: null,
    env: {},
    assets: '',
    versions: { svelte: '5' },
};

// add more mocks here if you need them

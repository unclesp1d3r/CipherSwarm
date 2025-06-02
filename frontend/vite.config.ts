import { svelteTesting } from '@testing-library/svelte/vite';
import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import path from 'path';

export default defineConfig({
    plugins: [tailwindcss(), sveltekit()],
    build: {
        outDir: 'build', // FastAPI will mount /frontend/build as static
        emptyOutDir: true,
    },
    server: {
        port: 5173, // For dev, accessible via http://localhost:5173
        strictPort: true,
        open: false,
    },
    resolve: {
        alias: {
            $lib: path.resolve("./src/lib"),
        },
    },
    preview: {
        port: 4173,
        strictPort: true,
    },
    test: {
        workspace: [
            {
                extends: './vite.config.ts',
                plugins: [svelteTesting()],
                test: {
                    name: 'client',
                    environment: 'jsdom',
                    clearMocks: true,
                    include: ['src/**/*.svelte.{test,spec}.{js,ts}'],
                    exclude: ['src/lib/server/**'],
                    setupFiles: ['./vitest-setup-client.ts']
                }
            },
            {
                extends: './vite.config.ts',
                test: {
                    name: 'server',
                    environment: 'node',
                    include: ['src/**/*.{test,spec}.{js,ts}'],
                    exclude: ['src/**/*.svelte.{test,spec}.{js,ts}']
                }
            }
        ]
    }
});

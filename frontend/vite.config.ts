import tailwindcss from '@tailwindcss/vite';
import { svelteTesting } from '@testing-library/svelte/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
    plugins: [tailwindcss(), sveltekit()],
    build: {
        sourcemap: true,
        outDir: 'build',
        emptyOutDir: true
    },
    server: { port: 5173, strictPort: true, open: false },
    test: {
        workspace: [
            {
                extends: './vite.config.ts',
                plugins: [svelteTesting()],
                test: {
                    name: 'client',
                    environment: 'jsdom',
                    clearMocks: true,
                    include: ['src/**/*.svelte.{test,spec}.{js,ts}', 'src/**/*.spec.ts'],
                    exclude: ['src/lib/server/**'],
                    setupFiles: ['./vitest-setup-client.ts']
                }
            }
        ]
    }
});

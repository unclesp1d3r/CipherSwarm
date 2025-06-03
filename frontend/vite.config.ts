import { defineConfig } from 'vitest/config';
import { sveltekit } from '@sveltejs/kit/vite';
import path from 'path';

export default defineConfig({
    plugins: [sveltekit()],
    resolve: {
        alias: {
            $lib: path.resolve("./src/lib"),
        },
    },
    server: {
        port: 5173,
        strictPort: true,
        open: false,
    },
    build: {
        sourcemap: true,
        outDir: 'build',
        emptyOutDir: true,
    },
    test: {
        include: ['src/**/*.{test,spec}.{js,ts}']
    }
});

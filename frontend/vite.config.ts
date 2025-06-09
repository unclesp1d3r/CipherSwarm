import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { svelteTesting } from '@testing-library/svelte/vite';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit(), svelteTesting({ resolveBrowser: true })],
	resolve: process.env.VITEST ? { conditions: ['browser'] } : undefined,
	build: {
		outDir: 'build',
		emptyOutDir: true
	},
	server: { port: 5173, strictPort: true, open: false },
	test: {
		name: 'client',
		environment: 'jsdom',
		clearMocks: true,
		include: ['src/**/*.svelte.{test,spec}.{js,ts}', 'src/**/*.spec.ts'],
		exclude: ['src/lib/server/**'],
		setupFiles: ['./vitest-setup-client.ts']
	}
});

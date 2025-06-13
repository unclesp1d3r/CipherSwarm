import { defineConfig } from '@playwright/test';

export default defineConfig({
	webServer: {
		command: 'pnpm run build && pnpm run preview',
		port: 4173,
		reuseExistingServer: true,
		env: {
			PLAYWRIGHT_TEST: 'true',
			NODE_ENV: 'test'
		}
	},
	testDir: 'e2e',
	workers: 2
});

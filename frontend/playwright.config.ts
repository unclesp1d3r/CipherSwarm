import { defineConfig } from '@playwright/test';

export default defineConfig({
    use: {
        video: {
            mode: 'retain-on-failure',
            size: { width: 640, height: 480 }
        },
    },
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

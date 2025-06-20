import { defineConfig, devices } from '@playwright/test';

/**
 * Playwright Configuration for E2E Tests
 *
 * This configuration is specifically for full-stack E2E tests that:
 * - Test against real Docker backend (PostgreSQL, FastAPI, MinIO, etc.)
 * - Use seeded test data for predictable scenarios
 * - Run in headless mode for CI/CD compatibility
 * - Include comprehensive browser coverage
 */
export default defineConfig({
    // Test directory for E2E tests
    testDir: './tests/e2e',

    // Global setup and teardown
    globalSetup: './tests/global-setup.e2e.ts',
    globalTeardown: './tests/global-teardown.e2e.ts',

    // Test configuration
    fullyParallel: false, // Run serially to avoid database conflicts
    forbidOnly: !!process.env.CI, // Fail CI if test.only is found
    retries: process.env.CI ? 2 : 0, // Retry on CI due to container startup timing
    workers: 1, // Single worker to avoid database conflicts

    // Reporter configuration
    reporter: [
        //['html', { outputFolder: 'test-results/e2e-report' }],
        ['json', { outputFile: 'test-results/e2e-results.json' }],
        ['junit', { outputFile: 'test-results/e2e-junit.xml' }],
        ['list'] // Show test progress in terminal
    ],

    // Output directory for test artifacts
    outputDir: 'test-results/e2e-artifacts',

    // Global test settings
    use: {
        // Base URL for the SvelteKit frontend (E2E Docker compose)
        baseURL: 'http://localhost:3005',

        // Browser settings
        headless: true,
        viewport: { width: 1280, height: 720 },

        // Test timeouts
        actionTimeout: 10_000, // 10 seconds for actions
        navigationTimeout: 30_000, // 30 seconds for navigation

        // Collect trace and video on failure
        trace: 'on-first-retry',
        video: 'retain-on-failure',
        screenshot: 'only-on-failure',

        // Additional context options
        locale: 'en-US',
        timezoneId: 'America/New_York',

        // Ignore HTTPS errors (for local development)
        ignoreHTTPSErrors: true
    },

    // Test timeout
    timeout: 60_000, // 1 minute per test

    // Expect timeout for assertions
    expect: {
        timeout: 10_000 // 10 seconds for expect assertions
    },

    // Browser projects for cross-browser testing
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] }
        }
        // },
        // {
        // 	name: 'firefox',
        // 	use: { ...devices['Desktop Firefox'] }
        // }
    ],

    // Web server configuration (not used - we rely on Docker compose)
    // The frontend is served by the Docker compose stack
    webServer: undefined
});

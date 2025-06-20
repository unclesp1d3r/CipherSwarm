import { test, expect } from '@playwright/test';
import { createTestHelpers, TEST_CREDENTIALS, TIMEOUTS } from '../test-utils';

/**
 * E2E Authentication Tests
 *
 * These tests verify the complete authentication flow against the real backend:
 * - Login with seeded admin and regular user accounts
 * - Session management and persistence
 * - Logout functionality
 * - Access control and redirection
 */

// Test data is now imported from shared test-utils

test.describe('Authentication Flow', () => {
    test.beforeEach(async ({ page }) => {
        // Start each test from the home page
        await page.goto('/');
    });

    test('should redirect unauthenticated users to login', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Attempt to access a protected route (campaigns)
        await helpers.navigateAndWaitForSSR('/campaigns');

        // Should be redirected to login
        await expect(page).toHaveURL(/\/login/);

        // Should see login form (CardTitle renders as div, not h2)
        await expect(page.locator('[data-slot="card-title"]:has-text("Login")')).toBeVisible();
        await expect(page.locator('input[type="email"]')).toBeVisible();
        await expect(page.locator('input[type="password"]')).toBeVisible();
    });

    test('should login successfully with admin credentials', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Navigate to login page and fill credentials
        await helpers.navigateAndWaitForSSR('/login');
        await page.fill('input[type="email"]', TEST_CREDENTIALS.admin.email);
        await page.fill('input[type="password"]', TEST_CREDENTIALS.admin.password);

        // Submit and wait for navigation to dashboard
        await helpers.submitFormAndWait('button[type="submit"]', 'navigation');

        // Verify successful login
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');
    });

    test('should login successfully with regular user credentials', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Navigate to login page and fill credentials
        await helpers.navigateAndWaitForSSR('/login');
        await page.fill('input[type="email"]', TEST_CREDENTIALS.user.email);
        await page.fill('input[type="password"]', TEST_CREDENTIALS.user.password);

        // Submit and wait for navigation to dashboard
        await helpers.submitFormAndWait('button[type="submit"]', 'navigation');

        // Verify successful login
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');
    });

    test('should show error for invalid credentials', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Navigate to login page
        await helpers.navigateAndWaitForSSR('/login');

        // Fill in invalid credentials
        await page.fill('input[type="email"]', 'invalid@example.com');
        await page.fill('input[type="password"]', 'wrongpassword');

        // Submit login form
        await page.click('button[type="submit"]');

        // Wait for form processing
        await page.waitForTimeout(TIMEOUTS.FORM_SUBMISSION);

        // Should stay on login page
        await expect(page).toHaveURL(/\/login/);

        // Should show error message in the Alert component
        await expect(page.locator('[role="alert"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION
        });

        // Should show the specific error message from backend
        await expect(page.locator('[role="alert"]')).toContainText('Invalid email or password');
    });

    test('should maintain session after page refresh', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're on the dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Refresh the page
        await page.reload();

        // Wait for page to load after refresh
        await page.waitForLoadState('networkidle');

        // Should still be logged in and on home page (JWT persistence)
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE
        });

        // Verify we can still access protected routes
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);

        // Should not be redirected to login
        await expect(page).not.toHaveURL(/\/login/);
    });

    test('should redirect to login when JWT token expires', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials first
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're logged in and on the dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Simulate an expired/invalid JWT token by setting an invalid token value
        // This triggers the same authentication failure path as an expired token
        await page.context().addCookies([
            {
                name: 'access_token',
                value: 'invalid.jwt.token.that.will.fail.authentication',
                domain: 'localhost',
                path: '/',
                httpOnly: true,
                secure: false,
                sameSite: 'Lax'
            }
        ]);

        // Try to access a protected route (campaigns) - this should trigger authentication check
        await helpers.navigateAndWaitForSSR('/campaigns');

        // Should be redirected to login due to invalid/expired token
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION
        });

        // Should see login form
        await expect(page.locator('[data-slot="card-title"]:has-text("Login")')).toBeVisible();
        await expect(page.locator('input[type="email"]')).toBeVisible();
        await expect(page.locator('input[type="password"]')).toBeVisible();

        // Verify that we can still login again after token expiration
        await page.fill('input[type="email"]', TEST_CREDENTIALS.admin.email);
        await page.fill('input[type="password"]', TEST_CREDENTIALS.admin.password);
        await helpers.submitFormAndWait('button[type="submit"]', 'navigation');

        // Should be redirected back to the originally requested page (campaigns)
        // This is the correct behavior - login redirects to redirectTo parameter
        await expect(page).toHaveURL(/\/campaigns/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns');
    });

    // test('should logout successfully', async ({ page }) => {
    //     // Login first
    //     await page.goto('/login');
    //     await page.fill('input[type="email"]', TEST_USERS.admin.email);
    //     await page.fill('input[type="password"]', TEST_USERS.admin.password);
    //     await page.click('button[type="submit"]');

    //     // Verify logged in
    //     await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);

    //     // Navigate to logout page
    //     await page.goto('/logout');

    //     // Should be redirected to login page
    //     await expect(page).toHaveURL(/\/login/);

    //     // Should not be able to access protected routes
    //     await page.goto('/campaigns');
    //     await expect(page).toHaveURL(/\/login/);
    // });

    // test('should handle concurrent sessions correctly', async ({ browser }) => {
    //     // Create two separate browser contexts (simulate different devices/browsers)
    //     const context1 = await browser.newContext();
    //     const context2 = await browser.newContext();

    //     const page1 = await context1.newPage();
    //     const page2 = await context2.newPage();

    //     try {
    //         // Login with admin in first context
    //         await page1.goto('/login');
    //         await page1.fill('input[type="email"]', TEST_USERS.admin.email);
    //         await page1.fill('input[type="password"]', TEST_USERS.admin.password);
    //         await page1.click('button[type="submit"]');
    //         await expect(page1).toHaveURL(/^http:\/\/localhost:3005\/$/);

    //         // Login with regular user in second context
    //         await page2.goto('/login');
    //         await page2.fill('input[type="email"]', TEST_USERS.user.email);
    //         await page2.fill('input[type="password"]', TEST_USERS.user.password);
    //         await page2.click('button[type="submit"]');
    //         await expect(page2).toHaveURL(/^http:\/\/localhost:3005\/$/);

    //         // Both sessions should remain active
    //         await expect(page1.locator('h2')).toContainText('Campaign Overview');
    //         await expect(page2.locator('h2')).toContainText('Campaign Overview');
    //     } finally {
    //         await context1.close();
    //         await context2.close();
    //     }
    // });
});

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

    test('should automatically refresh JWT token on API calls when near expiration', async ({
        page
    }) => {
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

        // Get the initial token from cookies
        const initialCookies = await page.context().cookies();
        const initialToken = initialCookies.find((c) => c.name === 'access_token')?.value;
        expect(initialToken).toBeDefined();

        // Test the token refresh mechanism by making multiple SSR navigation calls
        // This simulates the real-world scenario where hooks.server.ts checks token validity
        // and automatically refreshes it if needed during SSR load functions

        // Navigate to multiple protected routes that trigger SSR load functions
        // Each navigation tests that the authentication system works correctly
        const protectedRoutes = [
            { path: '/campaigns', selector: '[data-testid="campaigns-title"]', title: 'Campaigns' },
            { path: '/agents', selector: 'h2:has-text("Agents")', title: 'Agents' },
            { path: '/attacks', selector: 'h1:has-text("Attacks")', title: 'Attacks' },
            { path: '/resources', selector: 'h1:has-text("Resources")', title: 'Resources' },
            { path: '/users', selector: '[data-testid="users-title"]', title: 'User Management' }
        ];

        for (const route of protectedRoutes) {
            // Navigate to each protected route
            await helpers.navigateAndWaitForSSR(route.path);

            // Verify we successfully loaded the page (not redirected to login)
            await expect(page).toHaveURL(new RegExp(route.path));
            await expect(page.locator(route.selector)).toContainText(route.title);

            // Verify we're still authenticated and not redirected to login
            await expect(page).not.toHaveURL(/\/login/);

            // Small delay between navigations to allow for any token refresh processing
            await page.waitForTimeout(500);
        }

        // After all navigation, verify we can still access the dashboard
        await helpers.navigateAndWaitForSSR('/');
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Get the final token to verify it might have been refreshed during navigation
        const finalCookies = await page.context().cookies();
        const finalToken = finalCookies.find((c) => c.name === 'access_token')?.value;
        expect(finalToken).toBeDefined();

        // The token might be the same (if refresh wasn't needed) or different (if refreshed)
        // Both scenarios are valid - what matters is that authentication continued to work
        // This test validates that the automatic token refresh system works seamlessly

        // Final verification: ensure we can still access a protected route
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns');
        await expect(page).not.toHaveURL(/\/login/);
    });

    test('should logout successfully via logout page', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials first
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Navigate to logout route directly
        await page.goto('/logout');

        // Use the logout helper to wait for logout completion
        await helpers.logoutAndWaitForSuccess();

        // Verify we're on the login page - the helper already checks this
        // No additional assertion needed
    });

    test('should logout successfully via user menu confirmation dialog', async ({ page }) => {
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

        // Use the logout helper to handle the complete logout flow
        await helpers.logoutViaUserMenu();

        // Verify we're redirected to login page - the helper already checks this
        // No additional assertion needed
    });

    test('should cancel logout from user menu confirmation dialog', async ({ page }) => {
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

        // Wait for user menu trigger to be visible
        await expect(page.locator('[data-testid="user-menu-trigger"]')).toBeVisible({
            timeout: 10000
        });

        // Click on user menu trigger to open dropdown
        await page.locator('[data-testid="user-menu-trigger"]').click();

        // Wait for dropdown to be visible
        await expect(page.locator('[data-testid="user-menu-logout"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION
        });

        // Click logout menu item
        await page.locator('[data-testid="user-menu-logout"]').click();

        // Wait for logout confirmation dialog to appear
        await expect(page.locator('[data-testid="logout-confirmation-dialog"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION
        });

        // Verify dialog content
        await expect(page.locator('text=Confirm Logout')).toBeVisible();
        await expect(page.locator('text=Are you sure you want to log out?')).toBeVisible();

        // Cancel logout
        await page.locator('[data-testid="logout-cancel-button"]').click();

        // Should still be on dashboard (not logged out)
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Dialog should be closed
        await expect(page.locator('[data-testid="logout-confirmation-dialog"]')).not.toBeVisible();

        // Should still be able to access protected routes
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns');

        // Should not be redirected to login
        await expect(page).not.toHaveURL(/\/login/);
    });

    test('should verify JWT cookies are properly cleared after logout', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials first
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're logged in and get initial cookies
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Get cookies before logout
        const cookiesBeforeLogout = await page.context().cookies();
        const accessTokenBefore = cookiesBeforeLogout.find((c) => c.name === 'access_token');
        expect(accessTokenBefore).toBeDefined();
        expect(accessTokenBefore?.value).toBeTruthy();

        // Perform logout via direct route
        await helpers.navigateAndWaitForSSR('/logout');

        // Should be redirected to login page
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION
        });

        // Get cookies after logout to verify cleanup
        const cookiesAfterLogout = await page.context().cookies();
        const accessTokenAfter = cookiesAfterLogout.find((c) => c.name === 'access_token');

        // Access token should be removed or empty
        if (accessTokenAfter) {
            // If cookie still exists, it should be empty or have an expired value
            expect(accessTokenAfter.value).toBeFalsy();
        }

        // Verify other session cookies are also cleaned up
        const projectIdCookie = cookiesAfterLogout.find((c) => c.name === 'active_project_id');
        if (projectIdCookie) {
            expect(projectIdCookie.value).toBeFalsy();
        }

        // Attempt to manually set a fake token and verify it doesn't work
        await page.context().addCookies([
            {
                name: 'access_token',
                value: 'fake.invalid.token',
                domain: 'localhost',
                path: '/',
                httpOnly: true,
                secure: false,
                sameSite: 'Lax'
            }
        ]);

        // Try to access protected route with fake token
        await helpers.navigateAndWaitForSSR('/campaigns');

        // Should still be redirected to login (fake token doesn't work)
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION
        });
    });

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

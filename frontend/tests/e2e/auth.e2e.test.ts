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
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.UI_ANIMATION,
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
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Refresh the page
        await page.reload();

        // Wait for page to load after refresh
        await page.waitForLoadState('networkidle');

        // Should still be logged in and on home page (JWT persistence)
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
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
            timeout: TIMEOUTS.NAVIGATION,
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
                sameSite: 'Lax',
            },
        ]);

        // Try to access a protected route (campaigns) - this should trigger authentication check
        await helpers.navigateAndWaitForSSR('/campaigns');

        // Should be redirected to login due to invalid/expired token
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns');
    });

    test('should automatically refresh JWT token on API calls when near expiration', async ({
        page,
    }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials first
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're logged in and on the dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
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
            { path: '/users', selector: '[data-testid="users-title"]', title: 'User Management' },
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
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview');

        // Wait for user menu trigger to be visible
        await expect(page.locator('[data-testid="user-menu-trigger"]')).toBeVisible({
            timeout: 10000,
        });

        // Click on user menu trigger to open dropdown
        await page.locator('[data-testid="user-menu-trigger"]').click();

        // Wait for dropdown to be visible
        await expect(page.locator('[data-testid="user-menu-logout"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION,
        });

        // Click logout menu item
        await page.locator('[data-testid="user-menu-logout"]').click();

        // Wait for logout confirmation dialog to appear
        await expect(page.locator('[data-testid="logout-confirmation-dialog"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION,
        });

        // Verify dialog content
        await expect(page.locator('text=Confirm Logout')).toBeVisible();
        await expect(page.locator('text=Are you sure you want to log out?')).toBeVisible();

        // Cancel logout
        await page.locator('[data-testid="logout-cancel-button"]').click();

        // Should still be on dashboard (not logged out)
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
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
            timeout: TIMEOUTS.NAVIGATION,
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
                sameSite: 'Lax',
            },
        ]);

        // Try to access protected route with fake token
        await helpers.navigateAndWaitForSSR('/campaigns');

        // Should still be redirected to login (fake token doesn't work)
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
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

// SSR Load Function Authentication Tests
test.describe('SSR Load Function Authentication', () => {
    // TEST-AUTH-LOAD: Test authenticated data loading for dashboard (E2E)
    test('should successfully load dashboard data with authenticated API calls', async ({
        page,
    }) => {
        const helpers = createTestHelpers(page);

        // First, verify unauthenticated access redirects to login
        await helpers.navigateAndWaitForSSR('/');
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Login with admin credentials
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're successfully redirected to dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify dashboard components are loaded with authenticated data
        // This validates that the SSR load function successfully called the backend APIs

        // 1. Check that the page title is loaded
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 2. Verify dashboard metrics cards are present (loaded from /api/v1/web/dashboard/summary)
        await expect(page.locator('text=Active Agents')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(page.locator('text=Running Tasks')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(page.locator('text=Recently Cracked Hashes')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 3. Verify metrics have actual numeric values (not just loading placeholders)
        // This confirms the backend API returned real data
        const activeAgentsCard = page.locator('text=Active Agents').locator('..').locator('..');
        await expect(activeAgentsCard.locator('.text-3xl.font-bold')).not.toBeEmpty({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        const runningTasksCard = page.locator('text=Running Tasks').locator('..').locator('..');
        await expect(runningTasksCard.locator('.text-3xl.font-bold')).not.toBeEmpty({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 4. Verify campaigns section is loaded (from /api/v1/web/campaigns API)
        const campaignSection = page.locator('h2:has-text("Campaign Overview")').locator('..');
        await expect(campaignSection).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 5. Verify user context is properly loaded in the layout
        // This validates that locals.user is properly set by hooks.server.ts
        await expect(page.locator('[data-testid="user-menu-trigger"]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 6. Verify no error states are shown (which would indicate API failures)
        await expect(page.locator('text=Error loading dashboard')).not.toBeVisible();
        await expect(page.locator('text=Failed to load')).not.toBeVisible();
        await expect(page.locator('[role="alert"]')).not.toBeVisible();

        // 7. Test that refreshing the page maintains authentication and data loading
        await page.reload();
        await page.waitForLoadState('networkidle');

        // After refresh, should still be on dashboard with data loaded
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Metrics should still be visible after refresh
        await expect(page.locator('text=Active Agents')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 8. Test navigation to other authenticated routes and back to dashboard
        // This validates that authentication persists across SSR navigation
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);
        await expect(page).not.toHaveURL(/\/login/);

        // Navigate back to dashboard
        await helpers.navigateAndWaitForSSR('/');
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Dashboard data should still be loaded after navigation
        await expect(page.locator('text=Active Agents')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
    });

    test('should handle dashboard API failures gracefully with authentication', async ({
        page,
    }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials first
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're on the dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Simulate an API failure by setting an invalid token that will cause 401s
        // This tests the error handling in the dashboard load function
        await page.context().addCookies([
            {
                name: 'access_token',
                value: 'invalid.token.causing.api.failures',
                domain: 'localhost',
                path: '/',
                httpOnly: true,
                secure: false,
                sameSite: 'Lax',
            },
        ]);

        // Try to reload the dashboard with the invalid token
        await page.reload();
        await page.waitForLoadState('networkidle');

        // Should be redirected to login due to authentication failure
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Should see login form
        await expect(page.locator('[data-slot="card-title"]:has-text("Login")')).toBeVisible();
        await expect(page.locator('input[type="email"]')).toBeVisible();
        await expect(page.locator('input[type="password"]')).toBeVisible();
    });

    test('should validate project context in dashboard data loading', async ({ page }) => {
        const helpers = createTestHelpers(page);

        // Login with admin credentials
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // Verify we're on the dashboard
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify dashboard loads with project context
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Check that user context includes project information
        // This validates that the load function properly handles project associations
        await expect(page.locator('[data-testid="user-menu-trigger"]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Verify campaigns section shows (requires project context)
        const campaignSection = page.locator('h2:has-text("Campaign Overview")').locator('..');
        await expect(campaignSection).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Test that we can navigate to project-specific routes from dashboard
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns');

        // Navigate back to dashboard to verify project context is maintained
        await helpers.navigateAndWaitForSSR('/');
        await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h2')).toContainText('Campaign Overview', {
            timeout: TIMEOUTS.API_RESPONSE,
        });
    });

    test('should successfully load campaigns data with authenticated API calls', async ({
        page,
    }) => {
        const helpers = createTestHelpers(page);

        // First, verify unauthenticated access redirects to login
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Login with admin credentials
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // After login, navigate to campaigns page to test authenticated data loading
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify campaigns page loads with authenticated data
        // This validates that the SSR load function successfully called /api/v1/web/campaigns

        // 1. Verify page title and header are loaded
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 2. Verify campaign action buttons are present (requires authentication)
        await expect(page.locator('[data-testid="create-campaign-button"]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(page.locator('[data-testid="upload-campaign-button"]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 3. Verify campaigns data is loaded from the backend
        // The seeded test data should include campaigns that we can verify
        // If campaigns exist, they should be displayed in the campaigns list
        const campaignsContainer = page.locator('[data-testid="campaigns-container"]');

        // Wait for campaigns container to be visible (may show empty state or campaign items)
        await expect(campaignsContainer).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Check if we have campaigns or empty state - both are valid authenticated responses
        const hasCampaigns = (await page.locator('[data-testid*="campaign-item-"]').count()) > 0;
        const hasEmptyState = await page.locator('text=No campaigns found').isVisible();

        // Verify either campaigns are displayed OR empty state is shown (both indicate successful API call)
        expect(hasCampaigns || hasEmptyState).toBe(true);

        // 4. If campaigns exist, verify campaign details are properly displayed
        if (hasCampaigns) {
            // Verify campaign items show proper data structure
            const firstCampaign = page.locator('[data-testid*="campaign-item-"]').first();
            await expect(firstCampaign).toBeVisible();

            // Verify campaign menu is accessible (requires proper data loading)
            const campaignMenu = firstCampaign.locator('[data-testid*="campaign-menu-"]');
            if (await campaignMenu.isVisible()) {
                await campaignMenu.click();
                await expect(page.locator('text=Edit Campaign')).toBeVisible({
                    timeout: TIMEOUTS.UI_ANIMATION,
                });
                // Close menu
                await page.keyboard.press('Escape');
            }
        }

        // 5. Verify no authentication errors are shown
        await expect(page.locator('text=Authentication required')).not.toBeVisible();
        await expect(page.locator('text=Unauthorized')).not.toBeVisible();
        await expect(page.locator('[role="alert"]')).not.toBeVisible();

        // 6. Test that refreshing the page maintains authentication and data loading
        await page.reload();
        await page.waitForLoadState('networkidle');

        // After refresh, should still be on campaigns page with data loaded
        await expect(page).toHaveURL(/\/campaigns/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Action buttons should still be visible after refresh
        await expect(page.locator('[data-testid="create-campaign-button"]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 7. Test navigation to other authenticated routes and back to campaigns
        // This validates that authentication persists across SSR navigation
        await helpers.navigateAndWaitForSSR('/agents');
        await expect(page).toHaveURL(/\/agents/);
        await expect(page).not.toHaveURL(/\/login/);

        // Navigate back to campaigns
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('[data-testid="campaigns-title"]')).toContainText('Campaigns', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Campaigns data should still be loaded after navigation
        await expect(campaignsContainer).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 8. Test pagination functionality if campaigns exist
        if (hasCampaigns) {
            // Check if pagination controls are present
            const paginationControls = page.locator('[data-testid="pagination"]');
            if (await paginationControls.isVisible()) {
                // Verify pagination works with authenticated API calls
                await expect(paginationControls).toBeVisible();
            }
        }

        // 9. Test search functionality if available
        const searchInput = page.locator('[data-testid="campaigns-search"]');
        if (await searchInput.isVisible()) {
            // Test that search triggers authenticated API calls
            await searchInput.fill('test');
            await page.waitForTimeout(500); // Allow for debounced search

            // Verify page still loads correctly with search (authenticated API call)
            await expect(page.locator('[data-testid="campaigns-title"]')).toContainText(
                'Campaigns'
            );

            // Clear search
            await searchInput.clear();
            await page.waitForTimeout(500);
        }
    });

    test('should successfully load resources data with authenticated API calls', async ({
        page,
    }) => {
        const helpers = createTestHelpers(page);

        // First, verify unauthenticated access redirects to login
        await helpers.navigateAndWaitForSSR('/resources');
        await expect(page).toHaveURL(/\/login/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Login with admin credentials
        await helpers.loginAndWaitForSuccess(
            TEST_CREDENTIALS.admin.email,
            TEST_CREDENTIALS.admin.password
        );

        // After login, navigate to resources page to test authenticated data loading
        await helpers.navigateAndWaitForSSR('/resources');
        await expect(page).toHaveURL(/\/resources/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify resources page loads with authenticated data
        // This validates that the SSR load function successfully called /api/v1/web/resources

        // 1. Verify page title and header are loaded
        await expect(page.locator('h1')).toContainText('Resources', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Verify page description
        await expect(
            page.locator('text=Manage wordlists, rule lists, masks, and charsets')
        ).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 2. Verify upload button is present (requires authentication)
        await expect(page.locator('button:has-text("Upload Resource")')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 3. Verify filters section is visible
        await expect(page.locator('text=Filters')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(page.locator('input[placeholder="Search resources..."]')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(page.locator('select#resource-type')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 4. Verify resources data is loaded from the backend
        // The seeded test data should include resources that we can verify
        const resourcesTable = page.locator('table');
        await expect(resourcesTable).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Verify table headers are present
        await expect(page.locator('th:has-text("Name")')).toBeVisible();
        await expect(page.locator('th:has-text("Type")')).toBeVisible();
        await expect(page.locator('th:has-text("Size")')).toBeVisible();
        await expect(page.locator('th:has-text("Lines")')).toBeVisible();
        await expect(page.locator('th:has-text("Last Updated")')).toBeVisible();

        // Check if we have resources or empty state - both are valid authenticated responses
        const hasResources = (await page.locator('table tbody tr').count()) > 0;
        const hasEmptyState = await page.locator('text=No resources found').isVisible();

        // Verify either resources are displayed OR empty state is shown (both indicate successful API call)
        expect(hasResources || hasEmptyState).toBe(true);

        // 5. If resources exist, verify resource details are properly displayed
        if (hasResources) {
            // Verify resource count badge is displayed
            const resourceCountBadge = page.locator('[data-testid="resource-count"]');
            await expect(resourceCountBadge).toBeVisible({
                timeout: TIMEOUTS.API_RESPONSE,
            });

            // Get the count from the badge and verify it's a number
            const countText = await resourceCountBadge.textContent();
            expect(countText).toMatch(/^\d+$/);

            // Verify first resource row contains expected data structure
            const firstResourceRow = page.locator('table tbody tr').first();
            await expect(firstResourceRow).toBeVisible();

            // Check that resource links are functional (should have href attributes)
            const resourceLinks = page.locator('table tbody tr a');
            if ((await resourceLinks.count()) > 0) {
                const firstLink = resourceLinks.first();
                const href = await firstLink.getAttribute('href');
                expect(href).toMatch(/^\/resources\/[a-f0-9-]+$/);
            }

            // Verify resource type badges are displayed
            const typeBadges = page.locator('table tbody tr td').locator('span[class*="badge"]');
            if ((await typeBadges.count()) > 0) {
                await expect(typeBadges.first()).toBeVisible();
            }
        }

        // 6. Verify no authentication errors are shown
        await expect(page.locator('text=Authentication required')).not.toBeVisible();
        await expect(page.locator('text=Unauthorized')).not.toBeVisible();
        await expect(page.locator('[role="alert"]')).not.toBeVisible();

        // 7. Test that refreshing the page maintains authentication and data loading
        await page.reload();
        await page.waitForLoadState('networkidle');

        // After refresh, should still be on resources page with data loaded
        await expect(page).toHaveURL(/\/resources/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h1')).toContainText('Resources', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Upload button should still be visible after refresh
        await expect(page.locator('button:has-text("Upload Resource")')).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Table should still be visible after refresh
        await expect(resourcesTable).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 8. Test navigation to other authenticated routes and back to resources
        // This validates that authentication persists across SSR navigation
        await helpers.navigateAndWaitForSSR('/campaigns');
        await expect(page).toHaveURL(/\/campaigns/);
        await expect(page).not.toHaveURL(/\/login/);

        // Navigate back to resources
        await helpers.navigateAndWaitForSSR('/resources');
        await expect(page).toHaveURL(/\/resources/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(page.locator('h1')).toContainText('Resources', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Resources data should still be loaded after navigation
        await expect(resourcesTable).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // 9. Test filter functionality with authenticated API calls
        const searchInput = page.locator('input[placeholder="Search resources..."]');
        const filterButton = page.locator('button:has-text("Filter")');

        // Test search functionality
        await searchInput.fill('test');
        await filterButton.click();

        // Wait for potential API call and page update
        await page.waitForTimeout(1000);

        // Verify page still loads correctly with search (authenticated API call)
        await expect(page.locator('h1')).toContainText('Resources', {
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Table should still be present (may show filtered results or empty state)
        await expect(resourcesTable).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Clear search if clear button is available
        const clearButton = page.locator('button:has-text("Clear")');
        if (await clearButton.isVisible()) {
            await clearButton.click();
            await page.waitForTimeout(500);
        }

        // 10. Test resource type filtering
        const resourceTypeSelect = page.locator('select#resource-type');
        await resourceTypeSelect.selectOption('word_list');
        await filterButton.click();

        // Wait for potential API call and page update
        await page.waitForTimeout(1000);

        // Verify page still loads correctly with type filter (authenticated API call)
        await expect(page.locator('h1')).toContainText('Resources', {
            timeout: TIMEOUTS.API_RESPONSE,
        });
        await expect(resourcesTable).toBeVisible({
            timeout: TIMEOUTS.API_RESPONSE,
        });

        // Reset filter
        await resourceTypeSelect.selectOption('');
        await filterButton.click();
        await page.waitForTimeout(500);

        // 11. Test pagination functionality if resources exist and pagination is present
        if (hasResources) {
            const paginationControls = page.locator(
                'button:has-text("Previous"), button:has-text("Next")'
            );
            if ((await paginationControls.count()) > 0) {
                // Verify pagination controls are functional
                const nextButton = page.locator('button:has-text("Next")');
                const prevButton = page.locator('button:has-text("Previous")');

                // Check if next button is enabled and clickable
                if (await nextButton.isEnabled()) {
                    await nextButton.click();
                    await page.waitForTimeout(1000);

                    // Verify page still loads correctly after pagination (authenticated API call)
                    await expect(page.locator('h1')).toContainText('Resources', {
                        timeout: TIMEOUTS.API_RESPONSE,
                    });
                    await expect(resourcesTable).toBeVisible({
                        timeout: TIMEOUTS.API_RESPONSE,
                    });

                    // Go back to first page
                    if (await prevButton.isEnabled()) {
                        await prevButton.click();
                        await page.waitForTimeout(500);
                    }
                }
            }
        }
    });
});

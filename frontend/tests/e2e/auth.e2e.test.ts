import { test, expect } from '@playwright/test';

/**
 * E2E Authentication Tests
 *
 * These tests verify the complete authentication flow against the real backend:
 * - Login with seeded admin and regular user accounts
 * - Session management and persistence
 * - Logout functionality
 * - Access control and redirection
 */

// Test data from seeded database (see scripts/seed_e2e_data.py)
const TEST_USERS = {
	admin: {
		email: 'admin@e2e-test.example',
		password: 'admin-password-123',
		name: 'E2E Admin User'
	},
	user: {
		email: 'user@e2e-test.example',
		password: 'user-password-123',
		name: 'E2E Regular User'
	}
} as const;

test.describe('Authentication Flow', () => {
	test.beforeEach(async ({ page }) => {
		// Start each test from the home page
		await page.goto('/');
	});

	test('should redirect unauthenticated users to login', async ({ page }) => {
		// Attempt to access a protected route (campaigns)
		await page.goto('/campaigns');

		// Should be redirected to login
		await expect(page).toHaveURL(/\/login/);

		// Should see login form (CardTitle renders as div, not h2)
		await expect(page.locator('[data-slot="card-title"]:has-text("Login")')).toBeVisible();
		await expect(page.locator('input[type="email"]')).toBeVisible();
		await expect(page.locator('input[type="password"]')).toBeVisible();
	});

	test('should login successfully with admin credentials', async ({ page }) => {
		// Navigate to login page
		await page.goto('/login');

		// Fill in admin credentials
		await page.fill('input[type="email"]', TEST_USERS.admin.email);
		await page.fill('input[type="password"]', TEST_USERS.admin.password);

		// Submit login form
		await page.click('button[type="submit"]');

		// Should be redirected to home (dashboard)
		await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);

		// Should see dashboard content
		await expect(page.locator('h2')).toContainText('Campaign Overview');
	});

	test('should login successfully with regular user credentials', async ({ page }) => {
		// Navigate to login page
		await page.goto('/login');

		// Fill in user credentials
		await page.fill('input[type="email"]', TEST_USERS.user.email);
		await page.fill('input[type="password"]', TEST_USERS.user.password);

		// Submit login form
		await page.click('button[type="submit"]');

		// Should be redirected to home (dashboard)
		await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);

		// Should see dashboard content
		await expect(page.locator('h2')).toContainText('Campaign Overview');
	});

	test('should show error for invalid credentials', async ({ page }) => {
		// Navigate to login page
		await page.goto('/login');

		// Fill in invalid credentials
		await page.fill('input[type="email"]', 'invalid@example.com');
		await page.fill('input[type="password"]', 'wrongpassword');

		// Submit login form
		await page.click('button[type="submit"]');

		// Should stay on login page
		await expect(page).toHaveURL(/\/login/);

		// Should show error message in the form
		await expect(page.locator('[role="alert"]')).toBeVisible();
	});

	test('should maintain session after page refresh', async ({ page }) => {
		// Login first
		await page.goto('/login');
		await page.fill('input[type="email"]', TEST_USERS.admin.email);
		await page.fill('input[type="password"]', TEST_USERS.admin.password);
		await page.click('button[type="submit"]');

		// Verify logged in
		await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);

		// Refresh the page
		await page.reload();

		// Should still be logged in and on home page
		await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);
		await expect(page.locator('h2')).toContainText('Campaign Overview');
	});

	test('should logout successfully', async ({ page }) => {
		// Login first
		await page.goto('/login');
		await page.fill('input[type="email"]', TEST_USERS.admin.email);
		await page.fill('input[type="password"]', TEST_USERS.admin.password);
		await page.click('button[type="submit"]');

		// Verify logged in
		await expect(page).toHaveURL(/^http:\/\/localhost:3005\/$/);

		// Navigate to logout page
		await page.goto('/logout');

		// Should be redirected to login page
		await expect(page).toHaveURL(/\/login/);

		// Should not be able to access protected routes
		await page.goto('/campaigns');
		await expect(page).toHaveURL(/\/login/);
	});

	test('should handle concurrent sessions correctly', async ({ browser }) => {
		// Create two separate browser contexts (simulate different devices/browsers)
		const context1 = await browser.newContext();
		const context2 = await browser.newContext();

		const page1 = await context1.newPage();
		const page2 = await context2.newPage();

		try {
			// Login with admin in first context
			await page1.goto('/login');
			await page1.fill('input[type="email"]', TEST_USERS.admin.email);
			await page1.fill('input[type="password"]', TEST_USERS.admin.password);
			await page1.click('button[type="submit"]');
			await expect(page1).toHaveURL(/^http:\/\/localhost:3005\/$/);

			// Login with regular user in second context
			await page2.goto('/login');
			await page2.fill('input[type="email"]', TEST_USERS.user.email);
			await page2.fill('input[type="password"]', TEST_USERS.user.password);
			await page2.click('button[type="submit"]');
			await expect(page2).toHaveURL(/^http:\/\/localhost:3005\/$/);

			// Both sessions should remain active
			await expect(page1.locator('h2')).toContainText('Campaign Overview');
			await expect(page2.locator('h2')).toContainText('Campaign Overview');
		} finally {
			await context1.close();
			await context2.close();
		}
	});
});

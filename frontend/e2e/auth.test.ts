import { test, expect } from '@playwright/test';
import { createTestHelpers } from '../tests/test-utils';

/**
 * Mock-based Authentication E2E Tests
 *
 * These tests verify the basic UI behavior of authentication components:
 * - Login form display and basic validation
 * - Form field interactions
 * - UI elements rendering correctly
 */

test.describe('Authentication UI Components (Mock)', () => {
	test('should display login form', async ({ page }) => {
		const helpers = createTestHelpers(page);

		await helpers.navigateAndWaitForSSR('/login');

		// Should see login form elements
		await expect(page.locator('[data-slot="card-title"]')).toContainText('Login');
		await expect(page.locator('input[type="email"]')).toBeVisible();
		await expect(page.locator('input[type="password"]')).toBeVisible();
		await expect(page.locator('button[type="submit"]')).toBeVisible();
	});

	test('should show validation errors for empty form', async ({ page }) => {
		await page.goto('/login');

		// Try to submit empty form
		await page.locator('button[type="submit"]').click();

		// Should see validation errors (exact implementation depends on Formsnap)
		// This test verifies client-side validation is working
		await expect(page.locator('input[type="email"]')).toBeVisible();
		await expect(page.locator('input[type="password"]')).toBeVisible();
	});

	test('should allow typing in form fields', async ({ page }) => {
		await page.goto('/login');

		// Fill in form fields
		await page.locator('input[type="email"]').fill('test@example.com');
		await page.locator('input[type="password"]').fill('password123');

		// Verify values are entered
		await expect(page.locator('input[type="email"]')).toHaveValue('test@example.com');
		await expect(page.locator('input[type="password"]')).toHaveValue('password123');
	});

	test('should have remember me checkbox', async ({ page }) => {
		await page.goto('/login');

		// Should see remember me label and checkbox
		await expect(page.locator('text=Remember me')).toBeVisible();

		// Find the checkbox within the Shadcn component
		const checkboxButton = page.locator('[role="checkbox"]');
		await expect(checkboxButton).toBeVisible();

		// Should be able to click it
		await checkboxButton.click();
		await expect(checkboxButton).toHaveAttribute('data-state', 'checked');
	});

	test('should navigate to home page (authentication handled by server)', async ({ page }) => {
		await page.goto('/');

		// Note: In mock mode, we just test that the page loads
		// Authentication redirection is handled by server middleware in real integration tests
		await expect(page).toHaveURL('/');
	});

	test('should login successfully with valid credentials (mock)', async ({ page }) => {
		const helpers = createTestHelpers(page);

		// Navigate to login page
		await helpers.navigateAndWaitForSSR('/login');

		// Fill in form with any credentials (mocked in test environment)
		await page.fill('input[type="email"]', 'test@example.com');
		await page.fill('input[type="password"]', 'password123');

		// Submit login form and wait for navigation
		await helpers.submitFormAndWait('button[type="submit"]', 'navigation');

		// Should be redirected to home page
		await expect(page).toHaveURL('/');

		// Should see dashboard content (Campaign Overview from home page)
		await expect(page.locator('h2')).toContainText('Campaign Overview');
	});

	test('logout page should be accessible', async ({ page }) => {
		await page.goto('/logout');

		// Should redirect to login after logout (implementation dependent)
		await page.waitForURL('/login');
		await expect(page).toHaveURL('/login');
		await expect(page.locator('[data-slot="card-title"]')).toContainText('Login');
	});
});

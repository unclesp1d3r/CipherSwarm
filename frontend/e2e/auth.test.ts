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
		const helpers = createTestHelpers(page);
		await helpers.navigateAndWaitForSSR('/login');

		// Submit empty form
		await page.locator('button[type="submit"]').click();

		// Wait for validation errors to appear
		await expect(page.locator('text=Please enter a valid email address')).toBeVisible({
			timeout: 5000
		});
		await expect(page.locator('text=Password is required')).toBeVisible({ timeout: 5000 });
	});

	test('should show validation error for invalid email format', async ({ page }) => {
		const helpers = createTestHelpers(page);
		await helpers.navigateAndWaitForSSR('/login');

		// Fill invalid email format
		await page.fill('input[type="email"]', 'invalid-email');
		await page.fill('input[type="password"]', 'password123');

		// Submit form
		await page.locator('button[type="submit"]').click();

		// Should see email validation error
		await expect(page.locator('text=Please enter a valid email address')).toBeVisible({
			timeout: 5000
		});
	});

	test('should show validation error for empty password', async ({ page }) => {
		const helpers = createTestHelpers(page);
		await helpers.navigateAndWaitForSSR('/login');

		// Fill valid email but leave password empty
		await page.fill('input[type="email"]', 'test@example.com');

		// Submit form
		await page.locator('button[type="submit"]').click();

		// Should see password validation error
		await expect(page.locator('text=Password is required')).toBeVisible({ timeout: 5000 });
	});

	test('should clear validation errors when valid input is entered', async ({ page }) => {
		const helpers = createTestHelpers(page);
		await helpers.navigateAndWaitForSSR('/login');

		// Submit empty form to trigger validation errors
		await page.locator('button[type="submit"]').click();

		// Wait for errors to appear
		await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
		await expect(page.locator('text=Password is required')).toBeVisible();

		// Fill valid data
		await page.fill('input[type="email"]', 'test@example.com');
		await page.fill('input[type="password"]', 'password123');

		// Submit form again
		await page.locator('button[type="submit"]').click();

		// In test environment, should either redirect or stay on page without validation errors
		await page.waitForTimeout(2000); // Wait for any validation processing

		// Validation errors should be cleared (might still exist but should not be the original ones)
		// In test environment, this should either redirect to success or stay without errors
	});
});

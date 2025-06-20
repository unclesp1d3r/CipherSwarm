import { expect, type Page, type Locator } from '@playwright/test';

/**
 * Standard timeout values for animated UI components
 * These values account for CSS transitions and animations used in Shadcn-Svelte components
 */
export const TIMEOUTS = {
	// Modal and dialog animations
	MODAL_ANIMATION: 2000, // Time for modal to fully open/close

	// General UI animations
	UI_ANIMATION: 1000, // Standard UI transitions (buttons, form elements)

	// Form and input delays
	FORM_SUBMISSION: 3000, // Form submission processing
	INPUT_DEBOUNCE: 500, // Debounced input fields (search, etc.)

	// API and data loading
	API_RESPONSE: 5000, // API responses in test environment

	// Navigation and routing
	NAVIGATION: 10000 // Page navigation with SSR
} as const;

/**
 * Helper functions for common UI interaction patterns
 */
export class TestHelpers {
	constructor(private page: Page) {}

	/**
	 * Wait for a modal dialog to be fully visible and interactive
	 * Handles the common pattern of modal opening animations
	 */
	async waitForModal(modalSelector = '[role="dialog"]'): Promise<Locator> {
		const modal = this.page.locator(modalSelector);

		// Wait for modal to exist
		await expect(modal).toBeVisible({ timeout: TIMEOUTS.MODAL_ANIMATION });

		// Wait for any opening animations to complete
		await this.page.waitForTimeout(TIMEOUTS.UI_ANIMATION / 2);

		return modal;
	}

	/**
	 * Wait for modal with specific content to be ready
	 * Useful for modals that load content dynamically
	 */
	async waitForModalWithContent(contentText: string | RegExp): Promise<void> {
		await this.waitForModal();
		await expect(this.page.getByText(contentText)).toBeVisible({
			timeout: TIMEOUTS.API_RESPONSE
		});
	}

	/**
	 * Click a button and wait for modal to open
	 * Common pattern for "Details", "Edit", etc. buttons
	 */
	async clickAndWaitForModal(
		buttonSelector: string,
		modalContentText?: string | RegExp
	): Promise<Locator> {
		await this.page.locator(buttonSelector).click();

		if (modalContentText) {
			await this.waitForModalWithContent(modalContentText);
		} else {
			await this.waitForModal();
		}

		return this.page.locator('[role="dialog"]');
	}

	/**
	 * Wait for tab switching animations to complete
	 * Useful for modal tabs and navigation tabs
	 */
	async switchTabAndWait(tabSelector: string, expectedContent?: string | RegExp): Promise<void> {
		await this.page.locator(tabSelector).click();

		// Wait for tab switch animation
		await this.page.waitForTimeout(TIMEOUTS.UI_ANIMATION / 2);

		if (expectedContent) {
			await expect(this.page.getByRole('tabpanel')).toContainText(expectedContent, {
				timeout: TIMEOUTS.API_RESPONSE
			});
		}
	}

	/**
	 * Fill form field with debounce wait
	 * Useful for search inputs and auto-validating forms
	 */
	async fillWithDebounce(selector: string, value: string): Promise<void> {
		await this.page.locator(selector).fill(value);
		await this.page.waitForTimeout(TIMEOUTS.INPUT_DEBOUNCE);
	}

	/**
	 * Submit form and wait for processing
	 * Handles loading states and navigation
	 */
	async submitFormAndWait(
		submitButtonSelector: string,
		expectedResult?: 'navigation' | 'modal-close' | 'success-message'
	): Promise<void> {
		await this.page.locator(submitButtonSelector).click();

		switch (expectedResult) {
			case 'navigation':
				await this.page.waitForTimeout(TIMEOUTS.NAVIGATION);
				break;
			case 'modal-close':
				await expect(this.page.locator('[role="dialog"]')).not.toBeVisible({
					timeout: TIMEOUTS.MODAL_ANIMATION
				});
				break;
			case 'success-message':
				await this.page.waitForTimeout(TIMEOUTS.FORM_SUBMISSION);
				break;
			default:
				await this.page.waitForTimeout(TIMEOUTS.FORM_SUBMISSION);
		}
	}

	/**
	 * Wait for menu dropdown to be fully visible
	 * Handles dropdown animation delays
	 */
	async openMenuAndWait(menuButtonSelector: string): Promise<void> {
		await this.page.locator(menuButtonSelector).click();
		await this.page.waitForTimeout(TIMEOUTS.UI_ANIMATION / 2);
	}

	/**
	 * Navigate to page and wait for SSR content to be ready
	 * Handles the SSR + hydration process
	 */
	async navigateAndWaitForSSR(url: string, contentIndicator?: string | RegExp): Promise<void> {
		await this.page.goto(url);

		if (contentIndicator) {
			await expect(this.page.getByText(contentIndicator)).toBeVisible({
				timeout: TIMEOUTS.NAVIGATION
			});
		}

		// Wait for hydration to complete
		await this.page.waitForLoadState('networkidle');
	}

	/**
	 * Perform search with Enter key and wait for navigation to complete
	 * Handles SSR search functionality with proper navigation timing
	 */
	async searchAndWaitForNavigation(
		searchInputSelector: string,
		searchTerm: string
	): Promise<void> {
		const searchInput = this.page.locator(searchInputSelector);

		// Fill search input
		await searchInput.fill(searchTerm);

		// Press Enter to trigger search
		await searchInput.press('Enter');

		// Wait for navigation to complete with search parameter
		const expectedURL = new RegExp(`.*search=${encodeURIComponent(searchTerm)}.*`);
		await this.page.waitForURL(expectedURL, { timeout: TIMEOUTS.NAVIGATION });

		// Verify URL was updated correctly
		await expect(this.page).toHaveURL(expectedURL);
	}
}

/**
 * Test credentials for E2E testing
 * Must match the seeded data from scripts/seed_e2e_data.py
 */
export const TEST_CREDENTIALS = {
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

/**
 * Create test helpers instance for a page
 */
export function createTestHelpers(page: Page): TestHelpers {
	return new TestHelpers(page);
}

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
    UI_INTERACTION: 15000, // UI interactions like button clicks that may trigger navigation

    // Form and input delays
    FORM_SUBMISSION: 3000, // Form submission processing
    INPUT_DEBOUNCE: 500, // Debounced input fields (search, etc.)

    // API and data loading
    API_RESPONSE: 5000, // API responses in test environment

    // Navigation and routing
    NAVIGATION: 10000, // Page navigation with SSR
} as const;

/**
 * Helper functions for common UI interaction patterns
 */
export class TestHelpers {
    constructor(private page: Page) {}

    /**
     * Wait for a modal dialog to appear and be visible
     * Supports both AlertDialog and other modal types
     */
    async waitForModal(modalSelector = '[role="dialog"]'): Promise<Locator> {
        // Try multiple selectors for different modal types
        const selectors = [
            modalSelector,
            '[data-testid="logout-confirmation-dialog"]',
            '[role="alertdialog"]',
        ];

        let modal: Locator | null = null;

        // Try each selector until one is found
        for (const selector of selectors) {
            try {
                modal = this.page.locator(selector);
                await expect(modal).toBeVisible({ timeout: TIMEOUTS.MODAL_ANIMATION });
                break;
            } catch (error) {
                // Continue to next selector
                continue;
            }
        }

        if (!modal) {
            throw new Error(`No modal found with any of the selectors: ${selectors.join(', ')}`);
        }

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
            timeout: TIMEOUTS.API_RESPONSE,
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
                timeout: TIMEOUTS.API_RESPONSE,
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
        // Wait for button to be ready
        await expect(this.page.locator(submitButtonSelector)).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION,
        });
        await expect(this.page.locator(submitButtonSelector)).toBeEnabled({
            timeout: TIMEOUTS.UI_ANIMATION,
        });

        // Click with timeout to handle slow responses
        await this.page.locator(submitButtonSelector).click({
            timeout: TIMEOUTS.UI_INTERACTION,
        });

        switch (expectedResult) {
            case 'navigation':
                // Wait for navigation to complete with proper timeout
                await this.page.waitForLoadState('domcontentloaded', {
                    timeout: TIMEOUTS.NAVIGATION,
                });
                break;
            case 'modal-close':
                await expect(this.page.locator('[role="dialog"]')).not.toBeVisible({
                    timeout: TIMEOUTS.MODAL_ANIMATION,
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
                timeout: TIMEOUTS.NAVIGATION,
            });
        }

        // Wait for DOM content to be loaded and basic hydration to complete
        // Using 'domcontentloaded' instead of 'networkidle' to avoid issues with SSE connections
        await this.page.waitForLoadState('domcontentloaded');

        // Give a short pause for hydration to complete
        await this.page.waitForTimeout(1000);
    }

    /**
     * Reload page and wait for SSR content to be ready
     * Handles page refresh with proper SvelteKit 5 load state waiting
     */
    async reloadAndWaitForSSR(contentIndicator?: string | RegExp): Promise<void> {
        await this.page.reload();

        if (contentIndicator) {
            // Use more specific selectors to avoid strict mode violations
            if (typeof contentIndicator === 'string') {
                // Try to find the most specific match first (e.g., h1 heading)
                const headingSelector = `h1:has-text("${contentIndicator}")`;
                try {
                    await expect(this.page.locator(headingSelector)).toBeVisible({
                        timeout: TIMEOUTS.NAVIGATION,
                    });
                } catch {
                    // Fallback to first match if heading not found
                    await expect(this.page.getByText(contentIndicator).first()).toBeVisible({
                        timeout: TIMEOUTS.NAVIGATION,
                    });
                }
            } else {
                await expect(this.page.getByText(contentIndicator).first()).toBeVisible({
                    timeout: TIMEOUTS.NAVIGATION,
                });
            }
        }

        // Wait for DOM content to be loaded and basic hydration to complete
        // Using 'domcontentloaded' instead of 'networkidle' to avoid issues with SSE connections
        await this.page.waitForLoadState('domcontentloaded');

        // Give a short pause for hydration to complete
        await this.page.waitForTimeout(1000);
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

    /**
     * Perform login with credentials and wait for successful authentication
     * Reusable helper for E2E authentication tests
     */
    async loginAndWaitForSuccess(email: string, password: string): Promise<void> {
        // Navigate to login page
        await this.navigateAndWaitForSSR('/login');

        // Fill credentials
        await this.page.fill('input[type="email"]', email);
        await this.page.fill('input[type="password"]', password);

        // Submit and wait for navigation to dashboard
        await this.submitFormAndWait('button[type="submit"]', 'navigation');

        // Verify successful login by checking we're on dashboard
        await expect(this.page).toHaveURL(/^http:\/\/localhost:3005\/$/, {
            timeout: TIMEOUTS.NAVIGATION,
        });
        await expect(this.page.locator('h2')).toContainText('Campaign Overview');
    }

    /**
     * Perform logout and wait for successful redirect to login page
     * Handles both direct navigation to /logout and user menu logout
     */
    async logoutAndWaitForSuccess(): Promise<void> {
        // Wait for navigation to login page (logout redirects server-side)
        await this.page.waitForURL(/.*\/login.*/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify we're on the login page by checking for the login form
        await expect(this.page).toHaveURL(/.*\/login.*/, {
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Verify login form is visible using a more specific selector
        await expect(this.page.locator('input[type="email"]')).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION,
        });
    }

    /**
     * Open user menu and perform logout with confirmation
     * Handles the complete user menu logout flow
     */
    async logoutViaUserMenu(): Promise<void> {
        // Wait for the user menu trigger to be visible and clickable
        const userMenuTrigger = this.page.locator('[data-testid="user-menu-trigger"]');

        // Debug: Check if the trigger exists
        await expect(userMenuTrigger).toBeVisible({
            timeout: TIMEOUTS.NAVIGATION,
        });

        // Click the user menu trigger to open the dropdown
        await userMenuTrigger.click();

        // Wait for the dropdown menu to appear
        await this.page.waitForTimeout(TIMEOUTS.UI_ANIMATION);

        // Look for the logout option in the dropdown
        const logoutOption = this.page.locator('[data-testid="user-menu-logout"]');

        // Ensure the logout option is visible before clicking
        await expect(logoutOption).toBeVisible({
            timeout: TIMEOUTS.UI_ANIMATION,
        });

        // Click the logout option
        await logoutOption.click();

        // Wait for the logout confirmation dialog to appear
        const logoutDialog = await this.waitForModal('[data-testid="logout-confirmation-dialog"]');

        // Find and click the confirm logout button
        const confirmButton = logoutDialog.locator('button').filter({ hasText: 'Log Out' });
        await expect(confirmButton).toBeVisible({
            timeout: TIMEOUTS.MODAL_ANIMATION,
        });

        await confirmButton.click();

        // Wait for logout to complete and redirect to login
        await this.logoutAndWaitForSuccess();
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
        name: 'E2E Admin User',
    },
    user: {
        email: 'user@e2e-test.example',
        password: 'user-password-123',
        name: 'E2E Regular User',
    },
} as const;

/**
 * Create test helpers instance for a page
 */
export function createTestHelpers(page: Page): TestHelpers {
    return new TestHelpers(page);
}

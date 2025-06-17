import { test, expect, type Page } from '@playwright/test';

/**
 * E2E Project Management Tests
 *
 * These tests verify project and campaign management functionality:
 * - Project listing and navigation
 * - Campaign creation and management
 * - Project switching and context
 * - Data visibility and access control
 */

// Test data from seeded database (see scripts/seed_e2e_data.py)
const TEST_USERS = {
	admin: {
		email: 'admin@e2e-test.example',
		password: 'admin-password-123'
	}
} as const;

const TEST_PROJECTS = {
	alpha: 'E2E Test Project Alpha',
	beta: 'E2E Test Project Beta'
} as const;

const TEST_CAMPAIGNS = {
	alpha: 'E2E Test Campaign'
} as const;

// Helper function to login
async function loginAsAdmin(page: Page) {
	await page.goto('/login');
	await page.fill('input[type="email"]', TEST_USERS.admin.email);
	await page.fill('input[type="password"]', TEST_USERS.admin.password);
	await page.click('button[type="submit"]');
	await expect(page).toHaveURL(/\/dashboard/);
}

test.describe('Project Management', () => {
	test.beforeEach(async ({ page }) => {
		await loginAsAdmin(page);
	});

	test('should display seeded projects on dashboard', async ({ page }) => {
		// Navigate to projects section
		await page.click('[data-testid="projects-nav"]');

		// Should see both seeded projects
		await expect(page.locator('[data-testid="project-card"]')).toHaveCount(2);
		await expect(page.locator('text=' + TEST_PROJECTS.alpha)).toBeVisible();
		await expect(page.locator('text=' + TEST_PROJECTS.beta)).toBeVisible();
	});

	test('should navigate to project details', async ({ page }) => {
		// Go to projects
		await page.click('[data-testid="projects-nav"]');

		// Click on project alpha
		await page.click(`text=${TEST_PROJECTS.alpha}`);

		// Should be on project details page
		await expect(page).toHaveURL(/\/projects\/\d+/);
		await expect(page.locator('h1')).toContainText(TEST_PROJECTS.alpha);

		// Should see project description
		await expect(page.locator('[data-testid="project-description"]')).toContainText(
			'Primary test project for E2E testing'
		);
	});

	test('should switch between projects', async ({ page }) => {
		// Start with default project context
		await page.click('[data-testid="project-selector"]');

		// Should see both projects in dropdown
		await expect(page.locator('[data-testid="project-option"]')).toHaveCount(2);

		// Select project beta
		await page.click(`[data-testid="project-option"]:has-text("${TEST_PROJECTS.beta}")`);

		// Project context should update
		await expect(page.locator('[data-testid="current-project"]')).toContainText(
			TEST_PROJECTS.beta
		);

		// Content should update to show project beta data
		await expect(page.locator('[data-testid="project-info"]')).toContainText(
			'Secondary test project for multi-project scenarios'
		);
	});

	test('should create new project', async ({ page }) => {
		// Navigate to projects
		await page.click('[data-testid="projects-nav"]');

		// Click create project button
		await page.click('[data-testid="create-project-button"]');

		// Fill in project form
		await page.fill('[data-testid="project-name-input"]', 'E2E Created Project');
		await page.fill(
			'[data-testid="project-description-input"]',
			'Project created during E2E test'
		);

		// Submit form
		await page.click('[data-testid="submit-project-button"]');

		// Should see success message
		await expect(page.locator('[data-testid="success-message"]')).toContainText(
			'Project created successfully'
		);

		// Should see new project in list
		await expect(page.locator('text=E2E Created Project')).toBeVisible();
	});
});

test.describe('Campaign Management', () => {
	test.beforeEach(async ({ page }) => {
		await loginAsAdmin(page);
	});

	test('should display seeded campaigns', async ({ page }) => {
		// Navigate to campaigns
		await page.click('[data-testid="campaigns-nav"]');

		// Should see seeded campaign
		await expect(page.locator('[data-testid="campaign-card"]')).toHaveCount(1);
		await expect(page.locator('text=' + TEST_CAMPAIGNS.alpha)).toBeVisible();
	});

	test('should view campaign details', async ({ page }) => {
		// Navigate to campaigns
		await page.click('[data-testid="campaigns-nav"]');

		// Click on campaign
		await page.click(`text=${TEST_CAMPAIGNS.alpha}`);

		// Should be on campaign details page
		await expect(page).toHaveURL(/\/campaigns\/\d+/);
		await expect(page.locator('h1')).toContainText(TEST_CAMPAIGNS.alpha);

		// Should see campaign description
		await expect(page.locator('[data-testid="campaign-description"]')).toContainText(
			'Primary test campaign for E2E testing'
		);

		// Should see associated hash list
		await expect(page.locator('[data-testid="hash-list-info"]')).toContainText(
			'E2E Test Hash List'
		);
	});

	test('should show campaign statistics', async ({ page }) => {
		// Navigate to campaigns
		await page.click('[data-testid="campaigns-nav"]');

		// Click on campaign
		await page.click(`text=${TEST_CAMPAIGNS.alpha}`);

		// Should see statistics section
		await expect(page.locator('[data-testid="campaign-stats"]')).toBeVisible();

		// Should show basic stats (even if zero)
		await expect(page.locator('[data-testid="total-hashes"]')).toBeVisible();
		await expect(page.locator('[data-testid="cracked-hashes"]')).toBeVisible();
		await expect(page.locator('[data-testid="progress-percentage"]')).toBeVisible();
	});

	test('should create new campaign', async ({ page }) => {
		// Navigate to campaigns
		await page.click('[data-testid="campaigns-nav"]');

		// Click create campaign button
		await page.click('[data-testid="create-campaign-button"]');

		// Fill in campaign form
		await page.fill('[data-testid="campaign-name-input"]', 'E2E Created Campaign');
		await page.fill(
			'[data-testid="campaign-description-input"]',
			'Campaign created during E2E test'
		);

		// Select project (should default to current project context)
		await page.selectOption('[data-testid="project-select"]', { label: TEST_PROJECTS.alpha });

		// Select hash list
		await page.selectOption('[data-testid="hash-list-select"]', {
			label: 'E2E Test Hash List'
		});

		// Submit form
		await page.click('[data-testid="submit-campaign-button"]');

		// Should see success message
		await expect(page.locator('[data-testid="success-message"]')).toContainText(
			'Campaign created successfully'
		);

		// Should see new campaign in list
		await expect(page.locator('text=E2E Created Campaign')).toBeVisible();
	});

	test('should filter campaigns by project', async ({ page }) => {
		// Navigate to campaigns
		await page.click('[data-testid="campaigns-nav"]');

		// Switch to project beta
		await page.click('[data-testid="project-selector"]');
		await page.click(`[data-testid="project-option"]:has-text("${TEST_PROJECTS.beta}")`);

		// Should see no campaigns (beta project has no campaigns)
		await expect(page.locator('[data-testid="no-campaigns-message"]')).toContainText(
			'No campaigns found'
		);

		// Switch back to project alpha
		await page.click('[data-testid="project-selector"]');
		await page.click(`[data-testid="project-option"]:has-text("${TEST_PROJECTS.alpha}")`);

		// Should see the seeded campaign again
		await expect(page.locator('text=' + TEST_CAMPAIGNS.alpha)).toBeVisible();
	});
});

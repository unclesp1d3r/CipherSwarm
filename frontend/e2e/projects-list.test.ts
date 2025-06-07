import { test, expect } from '@playwright/test';

const mockProjects = [
	{
		id: 1,
		name: 'Project Alpha',
		description: 'First test project',
		private: false,
		archived_at: null,
		notes: 'Test notes',
		users: ['11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222'],
		created_at: '2024-06-15T12:00:00Z',
		updated_at: '2024-06-16T12:00:00Z'
	},
	{
		id: 2,
		name: 'Project Beta',
		description: 'Second test project',
		private: true,
		archived_at: null,
		notes: null,
		users: ['33333333-3333-3333-3333-333333333333'],
		created_at: '2024-06-17T12:00:00Z',
		updated_at: '2024-06-18T12:00:00Z'
	},
	{
		id: 3,
		name: 'Project Gamma',
		description: null,
		private: false,
		archived_at: '2024-06-19T12:00:00Z',
		notes: 'Archived project',
		users: [],
		created_at: '2024-06-15T12:00:00Z',
		updated_at: '2024-06-19T12:00:00Z'
	}
];

const mockProjectsResponse = {
	items: mockProjects,
	total: 3,
	page: 1,
	page_size: 20,
	search: null
};

const emptyProjectsResponse = {
	items: [],
	total: 0,
	page: 1,
	page_size: 20,
	search: null
};

test.describe('Projects List Page', () => {
	test.beforeEach(async ({ page }) => {
		// Mock successful API response by default
		await page.route('**/api/v1/web/projects*', async (route) => {
			const url = new URL(route.request().url());
			const search = url.searchParams.get('search');

			if (search === 'nonexistent') {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify({
						...emptyProjectsResponse,
						search: 'nonexistent'
					})
				});
			} else if (search === 'alpha') {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify({
						items: [mockProjects[0]],
						total: 1,
						page: 1,
						page_size: 20,
						search: 'alpha'
					})
				});
			} else {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify(mockProjectsResponse)
				});
			}
		});
	});

	test('displays projects list correctly', async ({ page }) => {
		await page.goto('/projects');

		// Check page title
		await expect(page.getByTestId('projects-title')).toHaveText('Project Management');

		// Check create button is present
		await expect(page.getByTestId('create-project-button')).toBeVisible();

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Check that projects are displayed
		const projectRows = page.getByTestId('project-row');
		await expect(projectRows).toHaveCount(3);

		// Check first project details
		const firstRow = projectRows.first();
		await expect(firstRow.getByTestId('project-name')).toHaveText('Project Alpha');
		await expect(firstRow.getByTestId('project-description')).toHaveText('First test project');
		await expect(firstRow.getByTestId('project-visibility')).toContainText('Public');
		await expect(firstRow.getByTestId('project-status')).toContainText('Active');
		await expect(firstRow.getByTestId('project-user-count')).toHaveText('2');

		// Check second project (private)
		const secondRow = projectRows.nth(1);
		await expect(secondRow.getByTestId('project-visibility')).toContainText('Private');

		// Check third project (archived)
		const thirdRow = projectRows.nth(2);
		await expect(thirdRow.getByTestId('project-status')).toContainText('Archived');
		await expect(thirdRow.getByTestId('project-description')).toHaveText('-');
	});

	test('search functionality works', async ({ page }) => {
		await page.goto('/projects');

		// Wait for initial load
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Test search
		await page.getByTestId('search-input').fill('alpha');
		await page.getByTestId('search-button').click();

		// Should show only matching project
		await expect(page.getByTestId('project-row')).toHaveCount(1);
		await expect(page.getByTestId('project-name')).toHaveText('Project Alpha');
	});

	test('search with enter key works', async ({ page }) => {
		await page.goto('/projects');

		// Wait for initial load
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Test search with enter key
		await page.getByTestId('search-input').fill('alpha');
		await page.getByTestId('search-input').press('Enter');

		// Should show only matching project
		await expect(page.getByTestId('project-row')).toHaveCount(1);
		await expect(page.getByTestId('project-name')).toHaveText('Project Alpha');
	});

	test('shows empty state when no projects found', async ({ page }) => {
		await page.goto('/projects');

		// Wait for initial load
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Search for non-existent project
		await page.getByTestId('search-input').fill('nonexistent');
		await page.getByTestId('search-button').click();

		// Should show search-specific empty state
		await expect(page.getByTestId('empty-state')).toContainText(
			'No projects found matching "nonexistent"'
		);
	});

	test('shows empty state with create button when no projects exist', async ({ page }) => {
		// Mock empty response for all requests
		await page.route('**/api/v1/web/projects*', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(emptyProjectsResponse)
			});
		});

		await page.goto('/projects');

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Should show empty state with create button
		await expect(page.getByTestId('empty-state')).toContainText('No projects found.');
		await expect(page.getByTestId('empty-state-create-button')).toBeVisible();
	});

	test('handles 403 error correctly', async ({ page }) => {
		await page.route('**/api/v1/web/projects*', async (route) => {
			await route.fulfill({
				status: 403,
				contentType: 'application/json',
				body: JSON.stringify({ detail: 'Not authorized' })
			});
		});

		await page.goto('/projects');

		// Should show access denied error
		await expect(page.getByTestId('error-message')).toHaveText(
			'Access denied. You must be an administrator to view projects.'
		);
	});

	test('handles general API error correctly', async ({ page }) => {
		await page.route('**/api/v1/web/projects*', async (route) => {
			await route.fulfill({
				status: 500,
				contentType: 'application/json',
				body: JSON.stringify({ detail: 'Internal server error' })
			});
		});

		await page.goto('/projects');

		// Should show generic error
		await expect(page.getByTestId('error-message')).toHaveText('Failed to load projects.');
	});

	test('action menu items are accessible', async ({ page }) => {
		await page.goto('/projects');

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Click on first project's action menu
		await page.getByTestId('project-actions-1').click();

		// Check menu items are visible
		await expect(page.getByTestId('project-view-1')).toBeVisible();
		await expect(page.getByTestId('project-edit-1')).toBeVisible();
		await expect(page.getByTestId('project-archive-1')).toBeVisible();
	});

	test('archived projects do not show archive option', async ({ page }) => {
		await page.goto('/projects');

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Click on archived project's action menu (project 3)
		await page.getByTestId('project-actions-3').click();

		// Check menu items - archive option should not be present
		await expect(page.getByTestId('project-view-3')).toBeVisible();
		await expect(page.getByTestId('project-edit-3')).toBeVisible();
		await expect(page.getByTestId('project-archive-3')).not.toBeVisible();
	});

	test('pagination works correctly', async ({ page }) => {
		// Mock paginated response - using page_size of 20 to match frontend default
		const paginatedResponse = {
			items: mockProjects.slice(0, 2), // Only first 2 projects
			total: 25, // Total that would require pagination
			page: 1,
			page_size: 20, // Match frontend default page size
			search: null
		};

		await page.route('**/api/v1/web/projects*', async (route) => {
			const url = new URL(route.request().url());
			const pageParam = url.searchParams.get('page');

			if (pageParam === '2') {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify({
						...paginatedResponse,
						items: [mockProjects[2]], // Third project on page 2
						page: 2
					})
				});
			} else {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify(paginatedResponse)
				});
			}
		});

		await page.goto('/projects');

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Check pagination info - should show 1-2 of 25 since we only returned 2 items
		await expect(page.getByTestId('pagination-info')).toContainText(
			'Showing 1-2 of 25 projects'
		);

		// Check pagination buttons are present
		await expect(page.getByTestId('pagination-next')).toBeVisible();
		await expect(page.getByTestId('pagination-page-2')).toBeVisible();

		// Click next page
		await page.getByTestId('pagination-page-2').click();

		// Should show different projects on page 2
		await expect(page.getByTestId('project-row')).toHaveCount(1);
		await expect(page.getByTestId('project-name')).toHaveText('Project Gamma');
	});

	test('date formatting works correctly', async ({ page }) => {
		await page.goto('/projects');

		// Wait for loading to complete
		await expect(page.getByTestId('loading-state')).not.toBeVisible();

		// Check that dates are formatted correctly (should be locale-specific)
		// Using mid-day UTC times to avoid timezone conversion issues
		const firstRow = page.getByTestId('project-row').first();
		await expect(firstRow.getByTestId('project-created')).toContainText('2024');
		await expect(firstRow.getByTestId('project-updated')).toContainText('2024');

		// Get the actual date text to ensure it's a valid date format
		const createdText = await firstRow.getByTestId('project-created').textContent();
		const updatedText = await firstRow.getByTestId('project-updated').textContent();

		// Verify they contain valid date-like patterns (month/day/year or day/month/year)
		expect(createdText).toMatch(/\d{1,2}\/\d{1,2}\/2024/);
		expect(updatedText).toMatch(/\d{1,2}\/\d{1,2}\/2024/);

		// Verify the dates are different (created vs updated)
		expect(createdText).not.toBe(updatedText);
	});

	test('loading state is shown initially', async ({ page }) => {
		// Delay the API response to test loading state
		await page.route('**/api/v1/web/projects*', async (route) => {
			await new Promise((resolve) => setTimeout(resolve, 100));
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockProjectsResponse)
			});
		});

		await page.goto('/projects');

		// Should show loading state initially
		await expect(page.getByTestId('loading-state')).toBeVisible();

		// Loading should eventually disappear
		await expect(page.getByTestId('loading-state')).not.toBeVisible();
	});
});

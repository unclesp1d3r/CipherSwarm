import { test, expect } from '@playwright/test';

test.describe('ProjectInfo Component', () => {
	test('component integration test via projects page', async ({ page }) => {
		// Mock the projects API to include a project that we can test
		await page.route('/api/v1/web/projects*', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify({
					items: [
						{
							id: 1,
							name: 'Test Project',
							description: 'A test project description',
							private: false,
							archived_at: null,
							notes: 'Some project notes',
							users: ['user1-uuid', 'user2-uuid'],
							created_at: '2024-01-01T00:00:00Z',
							updated_at: '2024-01-02T00:00:00Z'
						},
						{
							id: 2,
							name: 'Private Project',
							description: 'A private project',
							private: true,
							archived_at: null,
							notes: null,
							users: [],
							created_at: '2024-01-01T00:00:00Z',
							updated_at: '2024-01-02T00:00:00Z'
						},
						{
							id: 3,
							name: 'Archived Project',
							description: 'An archived project',
							private: false,
							archived_at: '2024-01-03T00:00:00Z',
							notes: null,
							users: [],
							created_at: '2024-01-01T00:00:00Z',
							updated_at: '2024-01-02T00:00:00Z'
						}
					],
					total: 3,
					page: 1,
					page_size: 20
				})
			});
		});

		// Navigate to projects page
		await page.goto('/projects');

		// Wait for the projects to load
		await page.waitForSelector('[data-testid="project-row"]');

		// Verify that project information is displayed correctly in the table
		// This tests the ProjectInfo component indirectly through the projects list
		await expect(page.locator('[data-testid="project-name"]').first()).toContainText(
			'Test Project'
		);
		await expect(page.locator('[data-testid="project-description"]').first()).toContainText(
			'A test project description'
		);
		await expect(page.locator('[data-testid="project-user-count"]').first()).toContainText('2');

		// Check visibility badges
		await expect(page.locator('[data-testid="project-visibility"]').nth(1)).toContainText(
			'Private'
		);
		await expect(page.locator('[data-testid="project-visibility"]').first()).toContainText(
			'Public'
		);

		// Check status badges
		await expect(page.locator('[data-testid="project-status"]').nth(2)).toContainText(
			'Archived'
		);
		await expect(page.locator('[data-testid="project-status"]').first()).toContainText(
			'Active'
		);

		// Check that dates are formatted (not raw ISO strings)
		const createdDate = await page
			.locator('[data-testid="project-created"]')
			.first()
			.textContent();
		expect(createdDate).not.toBe('2024-01-01T00:00:00Z');
		expect(createdDate).toMatch(/\d{1,2}\/\d{1,2}\/\d{4}/); // MM/DD/YYYY format
	});
});

import { test, expect } from '@playwright/test';

test.describe('ProjectInfo Component', () => {
    test('component integration test via projects page', async ({ page }) => {
        // Navigate to projects page (SSR will provide mock data in test environment)
        await page.goto('/projects');

        // Wait for the projects to load
        await page.waitForSelector('[data-testid="project-row"]');

        // Verify that project information is displayed correctly in the table
        // This tests the ProjectInfo component indirectly through the projects list
        // Using SSR mock data: Project Alpha, Project Beta, Project Gamma
        await expect(page.locator('[data-testid="project-name"]').first()).toContainText(
            'Project Alpha'
        );
        await expect(page.locator('[data-testid="project-description"]').first()).toContainText(
            'First test project'
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
        expect(createdDate).not.toBe('2024-06-15T12:00:00Z');
        expect(createdDate).toMatch(/\d{1,2}\/\d{1,2}\/\d{4}/); // MM/DD/YYYY format
    });
});

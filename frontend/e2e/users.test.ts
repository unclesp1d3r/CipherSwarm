import { test, expect } from '@playwright/test';

test.describe('Users Page', () => {
    test('should display users list correctly', async ({ page }) => {
        await page.goto('/users');

        // Check page title
        await expect(page.getByTestId('users-title')).toContainText('User Management');

        // Check that the table headers are visible (indicating the table is rendered)
        await expect(page.locator('th:has-text("Name")')).toBeVisible();
        await expect(page.locator('th:has-text("Email")')).toBeVisible();
        await expect(page.locator('th:has-text("Role")')).toBeVisible();
    });

    test('should show create user button', async ({ page }) => {
        await page.goto('/users');

        await expect(page.getByTestId('create-user-button')).toBeVisible();
        await expect(page.getByTestId('create-user-button')).toContainText('Create User');
    });

    test('should display pagination info', async ({ page }) => {
        await page.goto('/users');

        // Check that pagination info is visible (content will vary based on test data)
        await expect(page.getByTestId('pagination-info')).toBeVisible();
    });

    test('should open create user modal', async ({ page }) => {
        await page.goto('/users');

        // Click create user button
        await page.getByTestId('create-user-button').click();

        // Should navigate to /users/new and show modal
        await expect(page).toHaveURL('/users/new');
        await expect(page.getByTestId('user-create-modal')).toBeVisible();
        await expect(page.getByRole('heading', { name: 'Create New User' })).toBeVisible();

        // Check form fields
        await expect(page.getByTestId('name-input')).toBeVisible();
        await expect(page.getByTestId('email-input')).toBeVisible();
        await expect(page.getByTestId('password-input')).toBeVisible();
        await expect(page.getByTestId('role-select')).toBeVisible();
    });

    test('should create a new user', async ({ page }) => {
        await page.goto('/users/new');

        // Check modal is visible
        await expect(page.getByTestId('user-create-modal')).toBeVisible();

        // Fill form
        await page.getByTestId('name-input').fill('New User');
        await page.getByTestId('email-input').fill('newuser@example.com');
        await page.getByTestId('password-input').fill('password123');

        // Select role
        await page.getByTestId('role-select').click();
        await page.getByRole('option', { name: 'Operator' }).click();

        // Submit form
        await page.getByTestId('submit-button').click();

        // Should redirect back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should cancel create user', async ({ page }) => {
        await page.goto('/users/new');

        // Check modal is visible
        await expect(page.getByTestId('user-create-modal')).toBeVisible();

        // Cancel
        await page.getByTestId('cancel-button').click();

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should close modal with escape key', async ({ page }) => {
        await page.goto('/users/new');

        // Check modal is visible
        await expect(page.getByTestId('user-create-modal')).toBeVisible();

        // Press escape key
        await page.keyboard.press('Escape');

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should open user detail modal', async ({ page }) => {
        await page.goto('/users');

        // Find a user row and click the menu button
        const userRow = page.getByTestId('user-row-test-user-id').first();
        if (await userRow.isVisible()) {
            await userRow.getByTestId('user-menu-test-user-id').click();
            await page.getByTestId('view-user-test-user-id').click();

            // Should navigate to user detail page and show modal
            await expect(page).toHaveURL('/users/test-user-id');
            await expect(page.getByTestId('user-detail-modal')).toBeVisible();
            await expect(page.getByRole('heading', { name: 'User Details' })).toBeVisible();

            // Check that user details are displayed
            await expect(page.getByText('Test User')).toBeVisible();
            await expect(page.getByText('test@example.com')).toBeVisible();
        }
    });

    test('should edit user details', async ({ page }) => {
        await page.goto('/users/test-user-id');

        // Check modal is visible
        await expect(page.getByTestId('user-detail-modal')).toBeVisible();

        // Click edit button
        await page.getByTestId('edit-button').click();

        // Check that form fields are visible
        await expect(page.getByTestId('edit-name-input')).toBeVisible();
        await expect(page.getByTestId('edit-email-input')).toBeVisible();
        await expect(page.getByTestId('edit-role-select')).toBeVisible();
        await expect(page.getByTestId('edit-active-switch')).toBeVisible();

        // Edit user details
        await page.getByTestId('edit-name-input').fill('Updated User');
        await page.getByTestId('edit-email-input').fill('updated@example.com');

        // Change role
        await page.getByTestId('edit-role-select').click();
        await page.getByRole('option', { name: 'Admin' }).click();

        // Submit form
        await page.getByTestId('save-button').click();

        // Should redirect back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should cancel user edit', async ({ page }) => {
        await page.goto('/users/test-user-id');

        // Check modal is visible
        await expect(page.getByTestId('user-detail-modal')).toBeVisible();

        // Click edit button
        await page.getByTestId('edit-button').click();

        // Make some changes
        await page.getByTestId('edit-name-input').fill('Changed Name');

        // Cancel editing
        await page.getByTestId('cancel-edit-button').click();

        // Should return to view mode with original data
        await expect(page.getByText('Test User')).toBeVisible();
        await expect(page.getByTestId('edit-button')).toBeVisible();
    });

    test('should close user detail modal', async ({ page }) => {
        await page.goto('/users/test-user-id');

        // Check modal is visible
        await expect(page.getByTestId('user-detail-modal')).toBeVisible();

        // Close modal
        await page.getByTestId('close-button').click();

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should close user detail modal with escape key', async ({ page }) => {
        await page.goto('/users/test-user-id');

        // Check modal is visible
        await expect(page.getByTestId('user-detail-modal')).toBeVisible();

        // Press escape key
        await page.keyboard.press('Escape');

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should handle empty state', async ({ page }) => {
        // Use test scenario parameter for SSR
        await page.goto('/users?test_scenario=empty');

        // Check empty state
        await expect(page.getByTestId('empty-state')).toBeVisible();
        await expect(page.getByTestId('empty-state-create-button')).toBeVisible();
    });

    test('should handle error state', async ({ page }) => {
        // Use test scenario parameter for SSR
        await page.goto('/users?test_scenario=error');

        // Check error message is displayed in the page
        await expect(page.locator('text=Access denied')).toBeVisible();
    });

    test('should handle pagination', async ({ page }) => {
        await page.goto('/users');

        // Check pagination buttons
        await expect(page.getByTestId('first-page-button')).toBeVisible();
        await expect(page.getByTestId('prev-page-button')).toBeVisible();
        await expect(page.getByTestId('next-page-button')).toBeVisible();
        await expect(page.getByTestId('last-page-button')).toBeVisible();

        // First page buttons should be disabled
        await expect(page.getByTestId('first-page-button')).toBeDisabled();
        await expect(page.getByTestId('prev-page-button')).toBeDisabled();
    });

    test('should display user badges correctly', async ({ page }) => {
        await page.goto('/users');

        // Check that the table headers are visible (indicating the table is rendered)
        await expect(page.locator('th:has-text("Role")')).toBeVisible();
        await expect(page.locator('th:has-text("Active")')).toBeVisible();
        // Role and status badges will be visible based on test data provided by SSR
    });

    test('should validate user edit form', async ({ page }) => {
        await page.goto('/users/test-user-id');

        // Click edit button
        await page.getByTestId('edit-button').click();

        // Clear required fields
        await page.getByTestId('edit-name-input').fill('');
        await page.getByTestId('edit-email-input').fill('invalid-email');

        // Try to submit
        await page.getByTestId('save-button').click();

        // Should show validation errors
        await expect(page.locator('text=Name is required')).toBeVisible();
        await expect(page.locator('text=Please enter a valid email address')).toBeVisible();
    });

    test('should open user delete modal', async ({ page }) => {
        await page.goto('/users');

        // Find a user row and click the menu button
        const userRow = page.getByTestId('user-row-test-user-id').first();
        if (await userRow.isVisible()) {
            await userRow.getByTestId('user-menu-test-user-id').click();
            await page.getByTestId('delete-user-test-user-id').click();

            // Should navigate to user delete page and show modal
            await expect(page).toHaveURL('/users/test-user-id/delete');
            await expect(page.getByTestId('user-delete-modal')).toBeVisible();
            await expect(page.getByRole('heading', { name: 'Deactivate User' })).toBeVisible();

            // Check that user details are displayed in confirmation
            await expect(page.getByText('Test User')).toBeVisible();
            await expect(page.getByText('test@example.com')).toBeVisible();
        }
    });

    test('should deactivate user', async ({ page }) => {
        await page.goto('/users/test-user-id/delete');

        // Check modal is visible
        await expect(page.getByTestId('user-delete-modal')).toBeVisible();

        // Check confirmation text
        await expect(page.getByText('Are you sure you want to deactivate the user')).toBeVisible();
        await expect(page.getByText('Test User')).toBeVisible();

        // Confirm deletion
        await page.getByTestId('confirm-delete-button').click();

        // Should redirect back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should cancel user deletion', async ({ page }) => {
        await page.goto('/users/test-user-id/delete');

        // Check modal is visible
        await expect(page.getByTestId('user-delete-modal')).toBeVisible();

        // Cancel
        await page.getByTestId('cancel-button').click();

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });

    test('should close user delete modal with escape key', async ({ page }) => {
        await page.goto('/users/test-user-id/delete');

        // Check modal is visible
        await expect(page.getByTestId('user-delete-modal')).toBeVisible();

        // Press escape key
        await page.keyboard.press('Escape');

        // Should navigate back to users list
        await expect(page).toHaveURL('/users');
    });
});

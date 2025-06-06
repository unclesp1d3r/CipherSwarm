import { test, expect } from '@playwright/test';

// Mock data for testing
const mockUsers = {
    items: [
        {
            id: '123e4567-e89b-12d3-a456-426614174001',
            name: 'John Doe',
            email: 'john@example.com',
            is_active: true,
            is_verified: true,
            is_superuser: false,
            role: 'analyst',
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z'
        },
        {
            id: '123e4567-e89b-12d3-a456-426614174002',
            name: 'Jane Smith',
            email: 'jane@example.com',
            is_active: false,
            is_verified: true,
            is_superuser: true,
            role: 'admin',
            created_at: '2024-01-02T00:00:00Z',
            updated_at: '2024-01-02T00:00:00Z'
        }
    ],
    total: 2,
    page: 1,
    page_size: 20
};

const mockUser = {
    id: '123e4567-e89b-12d3-a456-426614174003',
    name: 'New User',
    email: 'newuser@example.com',
    is_active: true,
    is_verified: false,
    is_superuser: false,
    role: 'operator',
    created_at: '2024-01-03T00:00:00Z',
    updated_at: '2024-01-03T00:00:00Z'
};

test.describe('Users Page', () => {
    test.beforeEach(async ({ page }) => {
        // Mock the users API endpoint
        await page.route('**/api/v1/web/users*', async (route) => {
            const url = new URL(route.request().url());
            const search = url.searchParams.get('search');

            if (search === 'john') {
                await route.fulfill({
                    json: {
                        ...mockUsers,
                        items: [mockUsers.items[0]],
                        total: 1
                    }
                });
            } else {
                await route.fulfill({ json: mockUsers });
            }
        });

        // Mock create user API
        await page.route('**/api/v1/web/users', async (route) => {
            if (route.request().method() === 'POST') {
                await route.fulfill({ json: mockUser });
            }
        });

        // Mock update user API
        await page.route('**/api/v1/web/users/*', async (route) => {
            if (route.request().method() === 'PATCH') {
                await route.fulfill({ json: { ...mockUser, name: 'Updated User' } });
            } else if (route.request().method() === 'DELETE') {
                await route.fulfill({ json: { ...mockUser, is_active: false } });
            }
        });
    });

    test('should display users list correctly', async ({ page }) => {
        await page.goto('/users');

        // Check page title
        await expect(page.getByTestId('users-title')).toContainText('User Management');

        // Check that users are displayed
        await expect(
            page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174001')
        ).toBeVisible();
        await expect(
            page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174002')
        ).toBeVisible();

        // Check user data
        const firstRow = page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174001');
        await expect(firstRow).toContainText('John Doe');
        await expect(firstRow).toContainText('john@example.com');
        await expect(firstRow).toContainText('Analyst');

        const secondRow = page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174002');
        await expect(secondRow).toContainText('Jane Smith');
        await expect(secondRow).toContainText('jane@example.com');
        await expect(secondRow).toContainText('Admin');
    });

    test('should show create user button', async ({ page }) => {
        await page.goto('/users');

        await expect(page.getByTestId('create-user-button')).toBeVisible();
        await expect(page.getByTestId('create-user-button')).toContainText('Create User');
    });

    test('should display pagination info', async ({ page }) => {
        await page.goto('/users');

        await expect(page.getByTestId('pagination-info')).toContainText('Showing 1-2 of 2 users');
    });

    test('should handle search functionality', async ({ page }) => {
        await page.goto('/users');

        // Enter search term
        await page.getByTestId('search-input').fill('john');
        await page.getByTestId('search-button').click();

        // Wait for filtered results
        await page.waitForLoadState('networkidle');

        // Should only show John Doe
        await expect(
            page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174001')
        ).toBeVisible();
        await expect(
            page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174002')
        ).not.toBeVisible();
    });

    test('should handle search with Enter key', async ({ page }) => {
        await page.goto('/users');

        // Enter search term and press Enter
        await page.getByTestId('search-input').fill('john');
        await page.getByTestId('search-input').press('Enter');

        // Wait for filtered results
        await page.waitForLoadState('networkidle');

        // Should only show John Doe
        await expect(
            page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174001')
        ).toBeVisible();
    });

    test('should open create user modal', async ({ page }) => {
        await page.goto('/users');

        // Click create user button
        await page.getByTestId('create-user-button').click();

        // Check modal is visible
        await expect(page.getByTestId('user-create-modal')).toBeVisible();
        await expect(page.getByRole('heading', { name: 'Create New User' })).toBeVisible();

        // Check form fields
        await expect(page.getByTestId('name-input')).toBeVisible();
        await expect(page.getByTestId('email-input')).toBeVisible();
        await expect(page.getByTestId('password-input')).toBeVisible();
        await expect(page.getByTestId('role-select')).toBeVisible();
    });

    test('should create a new user', async ({ page }) => {
        await page.goto('/users');

        // Open create modal
        await page.getByTestId('create-user-button').click();

        // Fill form
        await page.getByTestId('name-input').fill('New User');
        await page.getByTestId('email-input').fill('newuser@example.com');
        await page.getByTestId('password-input').fill('password123');

        // Select role
        await page.getByTestId('role-select').click();
        await page.getByRole('option', { name: 'Operator' }).click();

        // Submit form
        await page.getByTestId('submit-button').click();

        // Wait for modal to close and page to refresh
        await page.waitForLoadState('networkidle');
        await expect(page.getByTestId('user-create-modal')).not.toBeVisible();
    });

    test('should cancel create user', async ({ page }) => {
        await page.goto('/users');

        // Open create modal
        await page.getByTestId('create-user-button').click();

        // Cancel
        await page.getByTestId('cancel-button').click();

        // Modal should be closed
        await expect(page.getByTestId('user-create-modal')).not.toBeVisible();
    });

    test('should open user detail modal', async ({ page }) => {
        await page.goto('/users');

        // Click user menu
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('view-user-123e4567-e89b-12d3-a456-426614174001').click();

        // Check modal is visible
        await expect(page.getByTestId('user-detail-modal')).toBeVisible();
        await expect(page.getByRole('heading', { name: 'User Details' })).toBeVisible();

        // Check user details are displayed
        await expect(page.getByTestId('user-detail-modal').getByText('John Doe')).toBeVisible();
        await expect(
            page.getByTestId('user-detail-modal').getByText('john@example.com')
        ).toBeVisible();
    });

    test('should edit user details', async ({ page }) => {
        await page.goto('/users');

        // Open detail modal
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('view-user-123e4567-e89b-12d3-a456-426614174001').click();

        // Click edit button
        await page.getByTestId('edit-button').click();

        // Check form fields are visible
        await expect(page.getByTestId('edit-name-input')).toBeVisible();
        await expect(page.getByTestId('edit-email-input')).toBeVisible();
        await expect(page.getByTestId('edit-role-select')).toBeVisible();

        // Update name
        await page.getByTestId('edit-name-input').fill('Updated User');

        // Save changes
        await page.getByTestId('save-button').click();

        // Wait for save to complete
        await page.waitForLoadState('networkidle');
    });

    test('should cancel edit user', async ({ page }) => {
        await page.goto('/users');

        // Open detail modal and start editing
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('view-user-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('edit-button').click();

        // Cancel editing
        await page.getByTestId('cancel-edit-button').click();

        // Should return to view mode
        await expect(page.getByTestId('edit-name-input')).not.toBeVisible();
        await expect(page.getByTestId('edit-button')).toBeVisible();
    });

    test('should open delete confirmation modal', async ({ page }) => {
        await page.goto('/users');

        // Click user menu and delete
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('delete-user-123e4567-e89b-12d3-a456-426614174001').click();

        // Check delete modal is visible
        await expect(page.getByTestId('user-delete-modal')).toBeVisible();
        await expect(page.getByRole('heading', { name: 'Deactivate User' })).toBeVisible();
        await expect(
            page.locator('text=Are you sure you want to deactivate the user')
        ).toBeVisible();
    });

    test('should confirm user deletion', async ({ page }) => {
        await page.goto('/users');

        // Open delete modal
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('delete-user-123e4567-e89b-12d3-a456-426614174001').click();

        // Confirm deletion
        await page.getByTestId('confirm-delete-button').click();

        // Wait for deletion to complete
        await page.waitForLoadState('networkidle');
        await expect(page.getByTestId('user-delete-modal')).not.toBeVisible();
    });

    test('should cancel user deletion', async ({ page }) => {
        await page.goto('/users');

        // Open delete modal
        await page.getByTestId('user-menu-123e4567-e89b-12d3-a456-426614174001').click();
        await page.getByTestId('delete-user-123e4567-e89b-12d3-a456-426614174001').click();

        // Cancel deletion
        await page.getByTestId('cancel-button').click();

        // Modal should be closed
        await expect(page.getByTestId('user-delete-modal')).not.toBeVisible();
    });

    test('should handle empty state', async ({ page }) => {
        // Mock empty response
        await page.route('**/api/v1/web/users*', async (route) => {
            await route.fulfill({
                json: {
                    items: [],
                    total: 0,
                    page: 1,
                    page_size: 20
                }
            });
        });

        await page.goto('/users');

        // Check empty state
        await expect(page.getByTestId('empty-state')).toBeVisible();
        await expect(page.getByTestId('empty-state-create-button')).toBeVisible();
    });

    test('should handle error state', async ({ page }) => {
        // Mock error response
        await page.route('**/api/v1/web/users*', async (route) => {
            await route.fulfill({
                status: 403,
                json: { detail: 'Access denied' }
            });
        });

        await page.goto('/users');

        // Check error message
        await expect(page.getByTestId('error-message')).toBeVisible();
        await expect(page.getByTestId('error-message')).toContainText('Access denied');
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

        const firstRow = page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174001');
        const secondRow = page.getByTestId('user-row-123e4567-e89b-12d3-a456-426614174002');

        // Check active status badges
        await expect(firstRow.locator('text=Yes').first()).toBeVisible(); // Active
        await expect(secondRow.locator('text=No').first()).toBeVisible(); // Not active

        // Check role badges
        await expect(firstRow.locator('text=Analyst')).toBeVisible();
        await expect(secondRow.locator('text=Admin')).toBeVisible();
    });
});

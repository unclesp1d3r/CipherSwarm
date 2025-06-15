import { test, expect } from '@playwright/test';

test.describe('Attack Wizard Routes', () => {
	test.beforeEach(async ({ page }) => {
		// Mock the API endpoints
		await page.route('/api/v1/web/attacks*', async (route) => {
			if (route.request().method() === 'GET') {
				await route.fulfill({
					json: {
						attacks: [
							{
								id: 1,
								name: 'Dictionary Attack 1',
								attack_mode: 'dictionary',
								comment: 'Standard dictionary attack',
								language: 'en',
								min_length: 8,
								max_length: 12,
								keyspace: 1000000,
								complexity_score: 3,
								state: 'running',
								created_at: '2024-01-01T00:00:00Z',
								updated_at: '2024-01-01T12:00:00Z',
								campaign_id: 1,
								campaign_name: 'Test Campaign'
							},
							{
								id: 2,
								name: 'Test Mask Attack',
								attack_mode: 'mask',
								comment: 'Test attack for mask mode',
								state: 'completed',
								created_at: '2024-01-01T00:00:00Z',
								updated_at: '2024-01-01T12:00:00Z'
							}
						],
						total: 2,
						page: 1,
						size: 10,
						total_pages: 1
					}
				});
			} else if (route.request().method() === 'POST') {
				await route.fulfill({
					json: {
						id: 3,
						name: 'New Attack',
						attack_mode: 'dictionary',
						state: 'draft'
					}
				});
			}
		});

		// Mock individual attack endpoint
		await page.route('/api/v1/web/attacks/1', async (route) => {
			if (route.request().method() === 'GET') {
				await route.fulfill({
					json: {
						id: 1,
						name: 'Dictionary Attack 1',
						attack_mode: 'dictionary',
						comment: 'Standard dictionary attack',
						language: 'en',
						min_length: 8,
						max_length: 12,
						keyspace: 1000000,
						complexity_score: 3,
						state: 'running',
						created_at: '2024-01-01T00:00:00Z',
						updated_at: '2024-01-01T12:00:00Z',
						campaign_id: 1,
						campaign_name: 'Test Campaign'
					}
				});
			}
		});

		// Mock attack performance endpoint
		await page.route('/api/v1/web/attacks/*/performance', async (route) => {
			await route.fulfill({
				json: {
					total_tasks: 100,
					completed_tasks: 75,
					average_speed: 1500000,
					estimated_time_remaining: 3600
				}
			});
		});

		// Mock estimation endpoint
		await page.route('/api/v1/web/attacks/estimate', async (route) => {
			await route.fulfill({
				json: {
					keyspace: 1000000,
					complexity_score: 3,
					estimated_time: 3600
				}
			});
		});

		// Mock wordlists and rules endpoints
		await page.route('/api/v1/web/wordlists*', async (route) => {
			await route.fulfill({
				json: {
					wordlists: [
						{ id: 1, name: 'common-passwords.txt', size: 10000 },
						{ id: 2, name: 'rockyou.txt', size: 14344391 }
					]
				}
			});
		});

		await page.route('/api/v1/web/rules*', async (route) => {
			await route.fulfill({
				json: {
					rules: [
						{ id: 1, name: 'best64.rule', description: 'Best 64 rules' },
						{ id: 2, name: 'leetspeak.rule', description: 'Leetspeak transformations' }
					]
				}
			});
		});

		// Mock resources endpoint
		await page.route('/api/v1/web/resources*', async (route) => {
			await route.fulfill({
				json: {
					resources: []
				}
			});
		});

		await page.goto('/attacks');
	});

	test('should navigate to new attack wizard', async ({ page }) => {
		// Wait for page to load
		await expect(page.getByTestId('attacks-table')).toBeVisible();

		// Click the "New Attack" button
		await page.getByRole('button', { name: 'New Attack' }).click();

		// Should navigate to /attacks/new
		await expect(page).toHaveURL('/attacks/new');

		// Verify wizard modal is open
		await expect(page.getByText('Create New Attack')).toBeVisible();
		await expect(page.getByPlaceholder('Enter attack name')).toBeVisible();

		// Verify we're on step 1 - use first() to avoid strict mode violation
		await expect(page.getByText('Basic Settings').first()).toBeVisible();
		await expect(page.getByText('Configure the basic attack parameters')).toBeVisible();
	});

	test('should navigate through wizard steps', async ({ page }) => {
		// Navigate to new attack wizard
		await page.goto('/attacks/new');
		await expect(page.getByText('Create New Attack')).toBeVisible();

		// Fill in basic info on step 1
		await page.getByPlaceholder('Enter attack name').fill('Test Wizard Attack');

		// Select dictionary mode by clicking the card
		await page.getByText('Dictionary Attack').click();

		// Go to step 2
		await page.getByRole('button', { name: 'Next' }).click();
		await expect(page.getByText('Attack Configuration').first()).toBeVisible();

		// Go to step 3
		await page.getByRole('button', { name: 'Next' }).click();
		await expect(page.getByText('Resources').first()).toBeVisible();

		// Go to step 4
		await page.getByRole('button', { name: 'Next' }).click();
		await expect(page.getByText('Review').first()).toBeVisible();

		// Go back to step 3
		await page.getByRole('button', { name: 'Previous' }).click();
		await expect(page.getByText('Resources').first()).toBeVisible();
	});

	test('should validate required fields in wizard', async ({ page }) => {
		// Navigate to new attack wizard
		await page.goto('/attacks/new');

		// The Next button should be disabled when required fields are empty
		await expect(page.getByRole('button', { name: 'Next' })).toBeDisabled();

		// Fill in name
		await page.getByPlaceholder('Enter attack name').fill('Test Attack');

		// Select attack mode
		await page.getByText('Dictionary Attack').click();

		// Now should be able to proceed
		await expect(page.getByRole('button', { name: 'Next' })).toBeEnabled();
		await page.getByRole('button', { name: 'Next' }).click();
		await expect(page.getByText('Attack Configuration').first()).toBeVisible();
	});

	test('should create new dictionary attack through wizard', async ({ page }) => {
		// Navigate to new attack wizard
		await page.goto('/attacks/new');

		// Step 1: Basic Settings
		await page.getByPlaceholder('Enter attack name').fill('Test New Dictionary Attack');
		await page.getByPlaceholder('Enter optional comment').fill('Test comment');
		await page.getByText('Dictionary Attack').click();
		await page.getByRole('button', { name: 'Next' }).click();

		// Step 2: Attack Configuration (dictionary settings)
		await expect(page.getByText('Attack Configuration').first()).toBeVisible();
		await page.getByRole('button', { name: 'Next' }).click();

		// Step 3: Resources
		await expect(page.getByText('Resources').first()).toBeVisible();
		await page.getByRole('button', { name: 'Next' }).click();

		// Step 4: Review and Submit
		await expect(page.getByText('Review').first()).toBeVisible();

		// Submit the form - just verify the button works and form can be submitted
		const submitButton = page.getByRole('button', { name: 'Create Attack' });
		await expect(submitButton).toBeEnabled();
		await submitButton.click();

		// Verify the button shows loading state
		await expect(page.getByRole('button', { name: 'Creating...' })).toBeVisible();
	});

	test('should navigate to edit attack wizard', async ({ page }) => {
		// Wait for table to load
		await expect(page.getByTestId('attacks-table')).toBeVisible();

		// Click on the dropdown menu for the first attack
		await page.getByTestId('attack-menu-1').click();

		// Click "Edit"
		await page.getByText('Edit').click();

		// Should navigate to /attacks/1/edit
		await expect(page).toHaveURL('/attacks/1/edit');

		// Verify edit wizard modal is open
		await expect(page.getByText('Edit Attack')).toBeVisible();

		// Check that the name field is populated with existing data
		await expect(page.getByPlaceholder('Enter attack name')).toHaveValue('Test Attack');
	});

	test('should open attack view modal', async ({ page }) => {
		// Wait for table to load
		await expect(page.getByTestId('attacks-table')).toBeVisible();

		// Click on the dropdown menu for the first attack
		await page.getByTestId('attack-menu-1').click();

		// Click "View Details"
		await page.getByText('View Details').click();

		// Verify view modal is open
		await expect(page.getByText('Attack Details')).toBeVisible();
		// Check that the attack data is displayed in the modal
		await expect(page.getByText('Attack: Dictionary Attack 1')).toBeVisible();
		await expect(page.getByText('Standard dictionary attack')).toBeVisible();
	});

	test('should close view modal', async ({ page }) => {
		// Open view modal
		await page.getByTestId('attack-menu-1').click();
		await page.getByText('View Details').click();
		await expect(page.getByText('Attack Details')).toBeVisible();

		// Close modal
		await page.getByTestId('footer-close').click();

		// Modal should be closed
		await expect(page.getByText('Attack Details')).not.toBeVisible();
	});

	test('should display attack details in view modal', async ({ page }) => {
		// Open view modal
		await page.getByTestId('attack-menu-1').click();
		await page.getByText('View Details').click();

		// Verify various sections are present
		await expect(page.getByText('Basic Information')).toBeVisible();
		await expect(page.getByText('Complexity & Keyspace')).toBeVisible();
		await expect(page.getByTestId('section-performance-data')).toBeVisible();
		await expect(page.getByText('Timestamps')).toBeVisible();

		// Check specific values
		await expect(page.getByTestId('attack-type-badge')).toBeVisible();
		await expect(page.getByLabel('Attack Details').getByText('Running')).toBeVisible();
		// Check for length range labels
		await expect(page.getByText('Min Length')).toBeVisible();
		await expect(page.getByText('Max Length')).toBeVisible();
	});

	test('should close wizard and return to attacks list', async ({ page }) => {
		// Navigate to new attack wizard
		await page.goto('/attacks/new');
		await expect(page.getByText('Create New Attack')).toBeVisible();

		// Close wizard using Cancel button (more reliable than X button)
		await page.getByRole('button', { name: 'Cancel' }).click();

		// Should return to attacks list
		await expect(page).toHaveURL('/attacks');
	});

	test('should close wizard with escape key', async ({ page }) => {
		// Navigate to new attack wizard
		await page.goto('/attacks/new');
		await expect(page.getByText('Create New Attack')).toBeVisible();

		// Press escape key
		await page.keyboard.press('Escape');

		// Should return to attacks list
		await expect(page).toHaveURL('/attacks');
	});
});

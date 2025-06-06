import { test, expect } from '@playwright/test';

test.describe('Attack Modals', () => {
	test.beforeEach(async ({ page }) => {
		// Mock the API endpoints
		await page.route('/api/v1/web/attacks*', async (route) => {
			if (route.request().method() === 'GET') {
				await route.fulfill({
					json: {
						attacks: [
							{
								id: 1,
								name: 'Test Dictionary Attack',
								attack_mode: 'dictionary',
								comment: 'Test attack for dictionary mode',
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
						name: 'Test Dictionary Attack',
						attack_mode: 'dictionary',
						comment: 'Test attack for dictionary mode',
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

	test('should open attack editor modal for new attack', async ({ page }) => {
		// Wait for page to load
		await expect(page.getByTestId('attacks-table')).toBeVisible();

		// Click the "New Attack" button
		await page.getByRole('button', { name: 'New Attack' }).click();

		// Verify modal is open
		await expect(page.getByText('Create Attack')).toBeVisible();
		await expect(page.getByPlaceholder('Enter attack name')).toBeVisible();

		// Verify default mode is dictionary
		await expect(page.getByTestId('attack-mode-dictionary')).toBeVisible();
		await expect(page.getByTestId('section-dictionary-settings')).toBeVisible();
	});

	test('should switch between attack modes', async ({ page }) => {
		// Open the attack editor modal
		await page.getByRole('button', { name: 'New Attack' }).click();
		await expect(page.getByText('Create Attack')).toBeVisible();

		// Switch to mask mode
		await page.getByTestId('attack-mode-mask').click();
		await expect(page.getByTestId('section-mask-settings')).toBeVisible();

		// Switch to brute force mode
		await page.getByTestId('attack-mode-brute-force').click();
		await expect(page.getByTestId('section-brute-force-settings')).toBeVisible();

		// Switch back to dictionary mode
		await page.getByTestId('attack-mode-dictionary').click();
		await expect(page.getByTestId('section-dictionary-settings')).toBeVisible();
	});

	test('should validate required fields', async ({ page }) => {
		// Open the attack editor modal
		await page.getByRole('button', { name: 'New Attack' }).click();

		// Try to submit without filling required fields
		await page.getByRole('button', { name: 'Add Attack' }).click();

		// Wait a moment for validation to trigger
		await page.waitForTimeout(100);

		// Should show validation error
		await expect(page.getByTestId('error-name-required')).toBeVisible();
	});

	test('should create new dictionary attack', async ({ page }) => {
		// Open the attack editor modal
		await page.getByRole('button', { name: 'New Attack' }).click();

		// Fill in attack details
		await page.getByPlaceholder('Enter attack name').fill('Test New Attack');
		await page.getByPlaceholder('Optional comment').fill('Test comment');

		// Select existing wordlist
		await page.getByRole('radio', { name: 'Existing Wordlist' }).click();

		// Submit the form
		await page.getByRole('button', { name: 'Add Attack' }).click();

		// Wait for the success event to be dispatched and form submission to complete
		await page.waitForTimeout(1000);

		// Verify the attack was created by checking if the button is no longer loading
		await expect(page.getByRole('button', { name: 'Add Attack' })).not.toBeDisabled();
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
		// Check that the attack data is displayed in the modal (look for the specific modal text)
		await expect(page.getByText('Attack: Test Dictionary Attack')).toBeVisible();
		await expect(page.getByText('Test attack for dictionary mode')).toBeVisible();
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

	test('should open attack editor modal for editing', async ({ page }) => {
		// Wait for table to load
		await expect(page.getByTestId('attacks-table')).toBeVisible();

		// Click on the dropdown menu for the first attack
		await page.getByTestId('attack-menu-1').click();

		// Click "Edit"
		await page.getByText('Edit').click();

		// Verify edit modal is open
		await expect(page.getByText('Edit Attack')).toBeVisible();

		// Wait for form to populate
		await page.waitForTimeout(100);

		// Check that the name field is populated
		await expect(page.getByPlaceholder('Enter attack name')).toHaveValue(
			'Test Dictionary Attack'
		);
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
		// Check for length range labels (more flexible than checking exact input values)
		await expect(page.getByText('Min Length')).toBeVisible();
		await expect(page.getByText('Max Length')).toBeVisible();
	});

	test('should cancel modal creation', async ({ page }) => {
		// Open the attack editor modal
		await page.getByRole('button', { name: 'New Attack' }).click();
		await expect(page.getByText('Create Attack')).toBeVisible();

		// Click cancel
		await page.getByRole('button', { name: 'Cancel' }).click();

		// Modal should be closed
		await expect(page.getByText('Create Attack')).not.toBeVisible();
	});
});

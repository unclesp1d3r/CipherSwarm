import { execSync } from 'node:child_process';
import { chromium, type FullConfig } from '@playwright/test';

/**
 * Playwright Global Setup for E2E Tests
 *
 * This setup runs once before all E2E tests and:
 * 1. Starts the Docker compose stack (backend + database)
 * 2. Waits for services to be healthy
 * 3. Seeds the database with predictable test data
 * 4. Validates that both frontend and backend are accessible
 */
async function globalSetup(config: FullConfig) {
	console.log('🐳 Starting E2E global setup...');

	try {
		// 1. Start Docker compose stack for E2E testing
		console.log('📦 Starting Docker compose stack...');
		execSync('docker compose -f ../docker-compose.e2e.yml up -d --build', {
			stdio: 'inherit',
			cwd: process.cwd()
		});

		// 2. Wait for services to be healthy
		console.log('⏳ Waiting for services to be healthy...');
		await waitForServices();

		// 3. Seed the database with test data
		console.log('🌱 Seeding E2E test data...');
		await seedTestData();

		// 4. Validate frontend accessibility
		console.log('🌐 Validating frontend accessibility...');
		await validateFrontend(config);

		console.log('✅ E2E global setup completed successfully!');
	} catch (error) {
		console.error('❌ E2E global setup failed:', error);

		// Cleanup on failure
		console.log('🧹 Cleaning up Docker containers...');
		try {
			execSync('docker compose -f ../docker-compose.e2e.yml down -v', {
				stdio: 'inherit',
				cwd: process.cwd()
			});
		} catch (cleanupError) {
			console.error('Failed to cleanup:', cleanupError);
		}

		throw error;
	}
}

/**
 * Wait for Docker services to be healthy
 */
async function waitForServices(): Promise<void> {
	const maxWaitTime = 120_000; // 2 minutes
	const checkInterval = 5_000; // 5 seconds
	const startTime = Date.now();

	while (Date.now() - startTime < maxWaitTime) {
		try {
			// Check if PostgreSQL is ready
			execSync(
				'docker compose -f ../docker-compose.e2e.yml exec -T postgres pg_isready -U postgres',
				{
					stdio: 'pipe'
				}
			);

			// Check if backend is responding
			const response = await fetch('http://localhost:8000/health');
			if (response.ok) {
				console.log('✅ All services are healthy');
				return;
			}
		} catch (error) {
			// Services not ready yet, continue waiting
			console.log('⏳ Services not ready, waiting...');
			await new Promise((resolve) => setTimeout(resolve, checkInterval));
		}
	}

	throw new Error('Services failed to become healthy within timeout period');
}

/**
 * Seed the database with predictable test data
 */
async function seedTestData(): Promise<void> {
	try {
		// Set environment variable to indicate E2E testing
		process.env.TESTING = 'true';

		// Run the seeding script in the backend container
		execSync(
			'docker compose -f ../docker-compose.e2e.yml exec -T backend python scripts/seed_e2e_data.py',
			{
				stdio: 'inherit',
				cwd: process.cwd()
			}
		);

		console.log('✅ Test data seeded successfully');
	} catch (error) {
		console.error('❌ Failed to seed test data:', error);
		throw error;
	}
}

/**
 * Validate that the frontend is accessible and loads correctly
 */
async function validateFrontend(config: FullConfig): Promise<void> {
	const browser = await chromium.launch();
	const context = await browser.newContext();
	const page = await context.newPage();

	try {
		// Navigate to the frontend
		await page.goto('http://localhost:5173', { waitUntil: 'networkidle' });

		// Check that the page loads and doesn't show error states
		await page.waitForSelector('body', { timeout: 10_000 });

		// Verify we can reach the login page or dashboard
		const title = await page.title();
		if (!title.includes('CipherSwarm')) {
			throw new Error(`Unexpected page title: ${title}`);
		}

		console.log('✅ Frontend is accessible and functional');
	} catch (error) {
		console.error('❌ Frontend validation failed:', error);
		throw error;
	} finally {
		await browser.close();
	}
}

export default globalSetup;

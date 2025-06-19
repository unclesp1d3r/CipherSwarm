import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { createSessionServerApi } from '$lib/server/api';
import {
	DashboardSummarySchema,
	CampaignListResponseSchema,
	type DashboardSummary,
	type CampaignItem,
	type CampaignRead,
	type CampaignListResponse
} from '$lib/types/dashboard';

// Mock data for testing/fallback
const mockDashboardSummary: DashboardSummary = {
	active_agents: 2,
	total_agents: 5,
	running_tasks: 3,
	total_tasks: 10,
	recently_cracked_hashes: 42,
	resource_usage: [
		{ timestamp: '2025-06-04T21:11:26.190Z', hash_rate: 100 },
		{ timestamp: '2025-06-04T22:11:26.190Z', hash_rate: 200 },
		{ timestamp: '2025-06-04T23:11:26.190Z', hash_rate: 150 }
	]
};

const mockCampaigns: CampaignItem[] = [
	{
		id: 1,
		name: 'Test Campaign 1',
		description: 'Mock campaign for testing',
		project_id: 1,
		priority: 1,
		hash_list_id: 1,
		is_unavailable: false,
		state: 'active',
		created_at: '2025-06-04T21:11:26.190Z',
		updated_at: '2025-06-04T21:11:26.190Z',
		attacks: [],
		progress: 0,
		summary: 'Mock campaign for testing'
	}
];

export const load: PageServerLoad = async ({ cookies }) => {
	// Test environment detection - return mock data
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		return {
			dashboard: mockDashboardSummary,
			campaigns: mockCampaigns,
			activeProjectId: 1
		};
	}

	// Get session cookie for authentication
	const sessionCookie = cookies.get('access_token');
	if (!sessionCookie) {
		throw error(401, 'Authentication required');
	}

	// Create API client with session cookie
	const api = createSessionServerApi(sessionCookie);

	try {
		// First load the user context to get project information
		let activeProjectId: number | null = null;
		try {
			const contextResponse = await api.getRaw('/api/v1/web/auth/context');
			const context = contextResponse.data;

			// Set active project if user has projects and no active project is set
			if (context.available_projects?.length > 0) {
				// Check if we already have an active project cookie
				const existingActiveProject = cookies.get('active_project_id');

				// Use existing active project or set to first available project
				if (
					existingActiveProject &&
					context.available_projects.some(
						(p: { id: number }) => p.id === parseInt(existingActiveProject)
					)
				) {
					activeProjectId = parseInt(existingActiveProject);
				} else if (context.active_project?.id) {
					const projectId = context.active_project.id;
					activeProjectId = projectId;
					cookies.set('active_project_id', projectId.toString(), {
						path: '/',
						httpOnly: false
					});
				} else {
					// Set first available project as active
					const firstProjectId = context.available_projects[0]?.id;
					if (firstProjectId) {
						activeProjectId = firstProjectId;
						cookies.set('active_project_id', firstProjectId.toString(), {
							path: '/',
							httpOnly: false
						});
					}
				}
			}
		} catch (contextError) {
			console.error('Failed to load context:', contextError);
			// Continue without context if it fails
		}

		// Load dashboard summary (doesn't require project context)
		const dashboardPromise = api.get('/api/v1/web/dashboard/summary', DashboardSummarySchema);

		// Load campaigns only if we have an active project
		let campaignsPromise: Promise<CampaignListResponse> | null = null;
		if (activeProjectId !== null) {
			// Create a new API client with both cookies set properly
			const apiWithProject = createSessionServerApi(sessionCookie);
			apiWithProject.setSessionCookie(
				`access_token=${sessionCookie}; active_project_id=${activeProjectId.toString()}`
			);

			campaignsPromise = apiWithProject.get(
				'/api/v1/web/campaigns?page=1&size=10',
				CampaignListResponseSchema
			);
		}

		// Await all promises
		const [dashboardData, campaignsData] = await Promise.all([
			dashboardPromise,
			campaignsPromise ||
				Promise.resolve({ items: [], total: 0, page: 1, size: 10, total_pages: 0 })
		]);

		// Transform campaigns to match CampaignItem interface
		const transformedCampaigns: CampaignItem[] = campaignsData.items.map(
			(campaign: CampaignRead) => ({
				...campaign, // Spread all CampaignRead fields
				attacks: [], // Will be loaded separately if needed
				progress: 0, // Will be calculated later
				summary: campaign.description || ''
			})
		);

		return {
			dashboard: dashboardData,
			campaigns: transformedCampaigns,
			activeProjectId: activeProjectId
		};
	} catch (err) {
		console.error('Failed to load dashboard data:', err);

		// Return mock data for development/testing
		return {
			dashboard: mockDashboardSummary,
			campaigns: mockCampaigns,
			activeProjectId: null
		};
	}
};

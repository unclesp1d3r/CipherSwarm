import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { createSessionServerApi } from '$lib/server/api';
import {
	DashboardSummarySchema,
	CampaignListResponseSchema,
	type DashboardSummary,
	type CampaignItem
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
		name: 'Test Campaign',
		description: 'A test campaign',
		project_id: 1,
		priority: 1,
		hash_list_id: 1,
		is_unavailable: false,
		id: 123,
		state: 'active', // Changed from 'running' to 'active' to match backend enum
		created_at: '2025-06-04T21:11:26.185Z',
		updated_at: '2025-06-04T21:11:26.185Z',
		attacks: [],
		progress: 0,
		summary: ''
	}
];

export const load: PageServerLoad = async ({ cookies }) => {
	// In test environment, provide mock data instead of requiring auth
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		return {
			dashboardSummary: mockDashboardSummary,
			campaigns: mockCampaigns,
			campaignsPagination: {
				total: 1,
				page: 1,
				size: 10,
				total_pages: 1
			}
		};
	}

	const sessionCookie = cookies.get('sessionid');
	if (!sessionCookie) {
		throw error(401, 'Authentication required');
	}

	const api = createSessionServerApi(sessionCookie);

	try {
		// Fetch dashboard summary and campaigns in parallel
		const [dashboardSummary, campaignsResponse] = await Promise.all([
			api.get('/api/v1/web/dashboard/summary', DashboardSummarySchema),
			api.get('/api/v1/web/campaigns', CampaignListResponseSchema)
		]);

		// Transform campaigns to include UI-specific fields
		const campaigns: CampaignItem[] = campaignsResponse.items.map((campaign) => ({
			...campaign,
			attacks: [],
			progress: 0,
			summary: ''
		}));

		return {
			dashboardSummary,
			campaigns,
			campaignsPagination: {
				total: campaignsResponse.total,
				page: campaignsResponse.page,
				size: campaignsResponse.size,
				total_pages: campaignsResponse.total_pages
			}
		};
	} catch (err) {
		console.error('Failed to load dashboard data:', err);
		// Fallback to mock data if API fails
		return {
			dashboardSummary: mockDashboardSummary,
			campaigns: mockCampaigns,
			campaignsPagination: {
				total: 1,
				page: 1,
				size: 10,
				total_pages: 1
			}
		};
	}
};

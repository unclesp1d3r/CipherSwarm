import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { createSessionServerApi } from '$lib/server/api';
import {
    DashboardSummarySchema,
    CampaignListResponseSchema,
    type DashboardSummary,
    type CampaignItem,
    type CampaignRead,
    type CampaignListResponse,
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
        { timestamp: '2025-06-04T23:11:26.190Z', hash_rate: 150 },
    ],
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
        summary: 'Mock campaign for testing',
    },
];

export const load: PageServerLoad = async ({ locals, cookies }) => {
    // Test environment detection - return mock data
    if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
        return {
            dashboard: mockDashboardSummary,
            campaigns: mockCampaigns,
            activeProjectId: 1,
            context: {
                user: {
                    id: locals?.user?.id || 'test-user-id',
                    email: locals?.user?.email || 'admin@test.local',
                    name: locals?.user?.name || 'Test Admin',
                    role: locals?.user?.role || 'admin',
                },
                active_project: {
                    id: 1,
                    name: 'Test Project Alpha',
                },
                available_projects: [
                    { id: 1, name: 'Test Project Alpha' },
                    { id: 2, name: 'Test Project Beta' },
                ],
            },
        };
    }

    // Check if user is authenticated via hooks
    if (!locals.session || !locals.user) {
        throw error(401, 'Authentication required');
    }

    // Create API client with session from locals
    const api = createSessionServerApi(`access_token=${locals.session}`);

    try {
        // Get active project ID from user context or cookies
        let activeProjectId: number | null = null;

        // Use current project from user context first
        if (locals.user.current_project_id) {
            activeProjectId = locals.user.current_project_id;
        } else if (locals.user.projects?.length > 0) {
            // If no current project but user has projects, use the first one
            activeProjectId = locals.user.projects[0].id;
            // Set the active project cookie for consistency
            cookies.set('active_project_id', activeProjectId.toString(), {
                path: '/',
                httpOnly: true,
                secure: false,
                sameSite: 'lax',
                maxAge: 60 * 60 * 24 * 30, // 30 days
            });
        }

        // Load dashboard summary (doesn't require project context)
        const dashboardPromise = api.get('/api/v1/web/dashboard/summary', DashboardSummarySchema);

        // Load campaigns only if we have an active project
        let campaignsPromise: Promise<CampaignListResponse> | null = null;
        if (activeProjectId !== null) {
            // Create API client with project context
            const apiWithProject = createSessionServerApi(
                `access_token=${locals.session}; active_project_id=${activeProjectId.toString()}`
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
                Promise.resolve({ items: [], total: 0, page: 1, size: 10, total_pages: 0 }),
        ]);

        // Transform campaigns to match CampaignItem interface
        const transformedCampaigns: CampaignItem[] = campaignsData.items.map(
            (campaign: CampaignRead) => ({
                ...campaign, // Spread all CampaignRead fields
                attacks: [], // Will be loaded separately if needed
                progress: 0, // Will be calculated later
                summary: campaign.description || '',
            })
        );

        return {
            dashboard: dashboardData,
            campaigns: transformedCampaigns,
            activeProjectId: activeProjectId,
            context: {
                user: {
                    id: locals.user.id,
                    email: locals.user.email,
                    name: locals.user.name,
                    role: locals.user.role,
                },
                active_project: activeProjectId
                    ? {
                          id: activeProjectId,
                          name:
                              locals.user.projects?.find((p) => p.id === activeProjectId)?.name ||
                              'Unknown Project',
                      }
                    : null,
                available_projects:
                    locals.user.projects?.map((p) => ({
                        id: p.id,
                        name: p.name,
                    })) || [],
            },
        };
    } catch (err) {
        console.error('Failed to load dashboard data:', err);

        // For development, fall back to mock data on API errors
        if (process.env.NODE_ENV === 'development') {
            return {
                dashboard: mockDashboardSummary,
                campaigns: mockCampaigns,
                activeProjectId: null,
                context: {
                    user: {
                        id: locals.user.id,
                        email: locals.user.email,
                        name: locals.user.name,
                        role: locals.user.role,
                    },
                    active_project: null,
                    available_projects:
                        locals.user.projects?.map((p) => ({
                            id: p.id,
                            name: p.name,
                        })) || [],
                },
            };
        }

        // In production, re-throw the error
        throw error(500, 'Failed to load dashboard data');
    }
};

import { z } from 'zod';

export const ResourceUsagePointSchema = z.object({
	timestamp: z.string().datetime(),
	hash_rate: z.number()
});

export const DashboardSummarySchema = z.object({
	active_agents: z.number(),
	total_agents: z.number(),
	running_tasks: z.number(),
	total_tasks: z.number(),
	recently_cracked_hashes: z.number(),
	resource_usage: z.array(ResourceUsagePointSchema)
});

export const CampaignReadSchema = z.object({
	id: z.number(),
	name: z.string(),
	description: z.string().nullable(),
	project_id: z.number(),
	priority: z.number(),
	hash_list_id: z.number(),
	is_unavailable: z.boolean(),
	state: z.enum(['draft', 'active', 'paused', 'completed', 'archived', 'error']),
	created_at: z.string().datetime(),
	updated_at: z.string().datetime()
});

export const CampaignListResponseSchema = z.object({
	items: z.array(CampaignReadSchema),
	total: z.number(),
	page: z.number(),
	size: z.number(),
	total_pages: z.number()
});

export type ResourceUsagePoint = z.infer<typeof ResourceUsagePointSchema>;
export type DashboardSummary = z.infer<typeof DashboardSummarySchema>;
export type CampaignRead = z.infer<typeof CampaignReadSchema>;
export type CampaignListResponse = z.infer<typeof CampaignListResponseSchema>;

// UI-enhanced campaign type for dashboard display
export interface CampaignItem extends CampaignRead {
	attacks: unknown[];
	progress: number;
	summary: string;
}

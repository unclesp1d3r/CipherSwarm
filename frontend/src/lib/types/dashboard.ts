import { z } from 'zod';
import type { CampaignRead } from '$lib/schemas/campaigns';
import type { DashboardSummary } from '$lib/schemas/dashboard';

// Import authoritative schemas
export {
    DashboardSummary,
    RecentActivityStats,
    QueueStatus,
    QueueStatusResponse,
    type DashboardSummary as DashboardSummaryType,
    type RecentActivityStats as RecentActivityStatsType,
    type QueueStatus as QueueStatusType,
    type QueueStatusResponse as QueueStatusResponseType,
} from '$lib/schemas/dashboard';

export {
    CampaignListResponse,
    type CampaignListResponse as CampaignListResponseType,
} from '$lib/schemas/campaigns';

// Re-export CampaignRead type for convenience
export type { CampaignRead } from '$lib/schemas/campaigns';

// Frontend-specific derived types for dashboard display
export const ResourceUsagePointSchema = z.object({
    timestamp: z.string().datetime(),
    hash_rate: z.number(),
});
export type ResourceUsagePoint = z.infer<typeof ResourceUsagePointSchema>;

// Backwards compatibility type with additional fields
export interface DashboardSummaryExtended extends DashboardSummary {
    // Legacy fields for backwards compatibility
    total_campaigns?: number;
    active_campaigns?: number;
    total_hash_lists?: number;
    total_hashes?: number;
    cracked_hashes?: number;
    crack_rate_percentage?: number;
}

// Campaign item type for dashboard usage
export interface CampaignItem extends CampaignRead {
    attacks: unknown[];
    progress: number;
    summary: string;
    status?: string; // For backwards compatibility (use state instead)
}

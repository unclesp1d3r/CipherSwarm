import type {
    CampaignRead,
    CampaignListResponse,
    CampaignMetrics,
    CampaignProgress,
} from '$lib/schemas/campaigns';

// Re-export schema types directly - no aliases needed
export type { CampaignRead, CampaignListResponse, CampaignMetrics, CampaignProgress };

// Campaign item type for dashboard usage that extends the schema
export interface CampaignItem extends CampaignRead {
    // Override optional fields to be required for UI consistency
    priority: number;
    is_unavailable: boolean;
    // Additional UI fields
    attacks: unknown[];
    progress: number;
    summary: string;
}

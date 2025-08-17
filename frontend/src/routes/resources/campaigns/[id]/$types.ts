import type { CampaignDetail, CampaignProgress, CampaignMetrics } from './+page.server';

export interface PageData {
    campaign: CampaignDetail;
    progress: CampaignProgress;
    metrics: CampaignMetrics;
}

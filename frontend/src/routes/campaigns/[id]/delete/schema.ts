import { z } from 'zod';

export const deleteCampaignSchema = z.object({
    message: z.string().optional()
});

export type DeleteCampaignSchema = typeof deleteCampaignSchema; 
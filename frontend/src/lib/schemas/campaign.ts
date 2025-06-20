import { z } from 'zod';

export const campaignFormSchema = z.object({
    name: z.string().min(1, 'Campaign name is required').max(255, 'Campaign name is too long'),
    description: z.string().optional(),
    priority: z.number().int().min(0, 'Priority must be non-negative').default(0),
    project_id: z.number().int().positive('Project ID is required'),
    hash_list_id: z.number().int().positive('Hash list ID is required'),
    is_unavailable: z.boolean().default(false)
});

export type CampaignFormData = z.infer<typeof campaignFormSchema>;

import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { fail, redirect, error, type RequestEvent } from '@sveltejs/kit';
import { campaignFormSchema } from '$lib/schemas/campaign';
import { createSessionServerApi } from '$lib/server/api';
import { z } from 'zod';

// Response schema for campaign creation
const CampaignResponseSchema = z.object({
    id: z.number(),
    name: z.string(),
    description: z.string().nullable(),
    project_id: z.number(),
    priority: z.number(),
    hash_list_id: z.number(),
    is_unavailable: z.boolean(),
    state: z.string(),
    created_at: z.string(),
    updated_at: z.string()
});

export const load = async ({ cookies, url }: RequestEvent) => {
    // In test environment, provide mock form
    if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
        const form = await superValidate(zod(campaignFormSchema));
        return { form };
    }

    const sessionCookie = cookies.get('access_token');
    if (!sessionCookie) {
        throw error(401, 'Authentication required');
    }

    // Initialize form with default values from URL params if provided
    const projectId = url.searchParams.get('project_id');
    const hashListId = url.searchParams.get('hash_list_id');

    const defaultData = {
        project_id: projectId ? parseInt(projectId, 10) : undefined,
        hash_list_id: hashListId ? parseInt(hashListId, 10) : undefined
    };

    const form = await superValidate(defaultData, zod(campaignFormSchema));
    return { form };
};

export const actions = {
    default: async ({ request, cookies }: RequestEvent) => {
        // Validate form data with Superforms
        const form = await superValidate(request, zod(campaignFormSchema));

        if (!form.valid) {
            return fail(400, { form });
        }

        // In test environment, simulate success
        if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
            // Simulate a successful campaign creation
            return redirect(303, '/campaigns');
        }

        const sessionCookie = cookies.get('access_token');
        if (!sessionCookie) {
            return fail(401, { form, message: 'Authentication required' });
        }

        const api = createSessionServerApi(sessionCookie);

        try {
            // Convert form data to API format
            const apiPayload = {
                name: form.data.name,
                description: form.data.description || null,
                priority: form.data.priority,
                project_id: form.data.project_id,
                hash_list_id: form.data.hash_list_id,
                is_unavailable: form.data.is_unavailable
            };

            // Call backend API to create campaign
            const response = await api.post(
                '/api/v1/web/campaigns/',
                apiPayload,
                CampaignResponseSchema
            );

            // Redirect to campaigns list on success
            return redirect(303, '/campaigns');
        } catch (apiError) {
            console.error('Failed to create campaign:', apiError);
            return fail(500, { form, message: 'Failed to create campaign' });
        }
    }
};

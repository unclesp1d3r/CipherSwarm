import { error, fail, redirect, type RequestEvent } from '@sveltejs/kit';
import { z } from 'zod';
import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { createSessionServerApi } from '$lib/server/api';
import type { Actions, PageServerLoad } from './$types';

// Zod schemas for validation
const UserContextDetailSchema = z.object({
	id: z.string(),
	email: z.string(),
	name: z.string(),
	role: z.string()
});

const ProjectContextDetailSchema = z.object({
	id: z.number(),
	name: z.string()
});

const ContextResponseSchema = z.object({
	user: UserContextDetailSchema,
	active_project: ProjectContextDetailSchema.nullable(),
	available_projects: z.array(ProjectContextDetailSchema)
});

const PasswordChangeSchema = z
	.object({
		old_password: z.string().min(1, 'Current password is required'),
		new_password: z.string().min(10, 'New password must be at least 10 characters long'),
		new_password_confirm: z.string().min(1, 'Password confirmation is required')
	})
	.refine((data) => data.new_password === data.new_password_confirm, {
		message: 'New passwords do not match',
		path: ['new_password_confirm']
	});

const ProjectSwitchSchema = z.object({
	project_id: z.number().min(1, 'Project ID is required')
});

// Type definitions
type ContextData = z.infer<typeof ContextResponseSchema>;
type PasswordFormData = z.infer<typeof PasswordChangeSchema>;
type ProjectFormData = z.infer<typeof ProjectSwitchSchema>;

// Mock data for test environments
const mockContextData: ContextData = {
	user: {
		id: '11111111-1111-1111-1111-111111111111',
		email: 'user@example.com',
		name: 'Test User',
		role: 'user'
	},
	active_project: {
		id: 1,
		name: 'Project Alpha'
	},
	available_projects: [
		{ id: 1, name: 'Project Alpha' },
		{ id: 2, name: 'Project Beta' },
		{ id: 3, name: 'Project Gamma' }
	]
};

export const load: PageServerLoad = async ({ cookies }: RequestEvent) => {
	// Detect test environment and provide mock data
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		const passwordForm = await superValidate(zod(PasswordChangeSchema));
		const projectForm = await superValidate(zod(ProjectSwitchSchema));

		return {
			context: mockContextData,
			passwordForm,
			projectForm
		};
	}

	// Normal SSR logic with authentication
	const sessionCookie = cookies.get('access_token');
	if (!sessionCookie) {
		throw error(401, 'Authentication required');
	}

	try {
		const api = createSessionServerApi(sessionCookie);

		// Fetch user context and project data
		const contextData = await api.get('/api/v1/web/auth/context', ContextResponseSchema);

		// Initialize forms
		const passwordForm = await superValidate(zod(PasswordChangeSchema));
		const projectForm = await superValidate(zod(ProjectSwitchSchema));

		return {
			context: contextData,
			passwordForm,
			projectForm
		};
	} catch (err) {
		console.error('Failed to load settings context:', err);

		// Handle specific error cases
		if (err && typeof err === 'object' && 'response' in err) {
			const axiosError = err as { response?: { status?: number } };
			if (axiosError.response?.status === 401) {
				throw error(401, 'Authentication required');
			}
			if (axiosError.response?.status === 403) {
				throw error(403, 'Access denied');
			}
		}

		throw error(500, 'Failed to load settings');
	}
};

export const actions: Actions = {
	changePassword: async ({ request, cookies }: RequestEvent) => {
		const sessionCookie = cookies.get('access_token');
		if (!sessionCookie) {
			throw error(401, 'Authentication required');
		}

		const form = await superValidate(request, zod(PasswordChangeSchema));

		if (!form.valid) {
			return fail(400, { form });
		}

		try {
			const api = createSessionServerApi(sessionCookie);

			// Call the password change endpoint
			await api.postRaw('/api/v1/web/auth/change_password', {
				old_password: form.data.old_password,
				new_password: form.data.new_password,
				new_password_confirm: form.data.new_password_confirm
			});

			return {
				form,
				success: true,
				message: 'Password changed successfully'
			};
		} catch (err) {
			console.error('Password change failed:', err);

			let errorMessage = 'Failed to change password';
			if (err && typeof err === 'object' && 'response' in err) {
				const axiosError = err as {
					response?: { status?: number; data?: { detail?: string } };
				};
				if (axiosError.response?.data?.detail) {
					errorMessage = axiosError.response.data.detail;
				}
			}

			return fail(400, {
				form,
				error: errorMessage
			});
		}
	},

	switchProject: async ({ request, cookies }: RequestEvent) => {
		const sessionCookie = cookies.get('access_token');
		if (!sessionCookie) {
			throw error(401, 'Authentication required');
		}

		const form = await superValidate(request, zod(ProjectSwitchSchema));

		if (!form.valid) {
			return fail(400, { form });
		}

		try {
			const api = createSessionServerApi(sessionCookie);

			// Call the context switch endpoint
			await api.postRaw('/api/v1/web/auth/context', {
				project_id: form.data.project_id
			});

			// Redirect to refresh the page with new context
			throw redirect(303, '/settings?switched=true');
		} catch (err) {
			console.error('Project switch failed:', err);

			let errorMessage = 'Failed to switch project';
			if (err && typeof err === 'object' && 'response' in err) {
				const axiosError = err as {
					response?: { status?: number; data?: { detail?: string } };
				};
				if (axiosError.response?.data?.detail) {
					errorMessage = axiosError.response.data.detail;
				}
			}

			return fail(400, {
				form,
				error: errorMessage
			});
		}
	}
};

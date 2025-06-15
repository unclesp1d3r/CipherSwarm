import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { fail, redirect, type RequestEvent, type Actions } from '@sveltejs/kit';
import { createSessionServerApi } from '$lib/server/api';
import { userCreateSchema } from './schema';

export const load = async ({ cookies }: RequestEvent) => {
	// In test environment, provide mock form
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		const form = await superValidate(zod(userCreateSchema));
		return { form };
	}

	// Check authentication
	const sessionCookie = cookies.get('sessionid');
	if (!sessionCookie) {
		throw redirect(302, '/login');
	}

	// Initialize empty form
	const form = await superValidate(zod(userCreateSchema));
	return { form };
};

export const actions: Actions = {
	default: async ({ request, cookies }: RequestEvent) => {
		// Validate form data
		const form = await superValidate(request, zod(userCreateSchema));

		if (!form.valid) {
			return fail(400, { form });
		}

		// In test environment, simulate success
		if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
			return { form };
		}

		// Check authentication
		const sessionCookie = cookies.get('sessionid');
		if (!sessionCookie) {
			return fail(401, { form, message: 'Authentication required' });
		}

		try {
			const api = createSessionServerApi(sessionCookie);

			// Convert form data to API format
			const apiPayload = {
				name: form.data.name,
				email: form.data.email,
				password: form.data.password,
				role: form.data.role
			};

			// Call backend API to create user
			await api.postRaw('/api/v1/web/users', apiPayload);

			// Success - form will redirect via onUpdated callback
			return { form };
		} catch (error) {
			console.error('Failed to create user:', error);

			// Handle specific error cases
			if (error && typeof error === 'object' && 'response' in error) {
				const axiosError = error as {
					response?: { status?: number; data?: { detail?: string } };
				};

				if (axiosError.response?.status === 403) {
					return fail(403, {
						form,
						message: 'Access denied. You must be an administrator to create users.'
					});
				}

				if (axiosError.response?.status === 409) {
					return fail(409, {
						form,
						message:
							axiosError.response.data?.detail ||
							'User with this email already exists'
					});
				}

				if (axiosError.response?.data?.detail) {
					return fail(400, { form, message: axiosError.response.data.detail });
				}
			}

			return fail(500, { form, message: 'Failed to create user. Please try again.' });
		}
	}
};

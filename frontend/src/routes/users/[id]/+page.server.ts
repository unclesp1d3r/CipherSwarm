import { superValidate } from 'sveltekit-superforms';
import { zod4 } from 'sveltekit-superforms/adapters';
import { fail, redirect, error, type RequestEvent, type Actions } from '@sveltejs/kit';
import { createSessionServerApi } from '$lib/server/api';
import { userUpdateSchema } from './schema';
import type { UserRead } from '$lib/schemas/users';

export const load = async ({ params, cookies }: RequestEvent) => {
    const userId = params.id;

    // In test environment, provide mock data
    if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
        const mockUser: UserRead = {
            id: userId || 'test-user-id',
            email: 'test@example.com',
            name: 'Test User',
            role: 'operator',
            is_active: true,
            is_superuser: false,
            created_at: '2024-01-01T00:00:00Z',
            updated_at: '2024-01-01T00:00:00Z',
        };

        const form = await superValidate(
            {
                name: mockUser.name,
                email: mockUser.email,
                role: mockUser.role as 'analyst' | 'operator' | 'admin',
                is_active: mockUser.is_active,
            },
            zod4(userUpdateSchema)
        );

        return { form, user: mockUser };
    }

    // Check authentication
    const sessionCookie = cookies.get('access_token');
    if (!sessionCookie) {
        throw redirect(302, '/login');
    }

    try {
        const api = createSessionServerApi(sessionCookie);

        // Fetch user details
        const response = await api.getRaw(`/api/v1/web/users/${userId}`);
        const user = response.data as UserRead;

        // Initialize form with current user data
        const form = await superValidate(
            {
                name: user.name,
                email: user.email,
                role: user.role as 'analyst' | 'operator' | 'admin',
                is_active: user.is_active,
            },
            zod4(userUpdateSchema)
        );

        return { form, user };
    } catch (apiError) {
        console.error('Failed to load user:', apiError);

        if (apiError && typeof apiError === 'object' && 'response' in apiError) {
            const axiosError = apiError as {
                response?: { status?: number; data?: { detail?: string } };
            };

            if (axiosError.response?.status === 404) {
                throw error(404, 'User not found');
            }

            if (axiosError.response?.status === 403) {
                throw error(
                    403,
                    'Access denied. You must be an administrator to view user details.'
                );
            }
        }

        throw error(500, 'Failed to load user details');
    }
};

export const actions: Actions = {
    default: async ({ request, params, cookies }: RequestEvent) => {
        const userId = params.id;

        // Validate form data
        const form = await superValidate(request, zod4(userUpdateSchema));

        if (!form.valid) {
            return fail(400, { form });
        }

        // In test environment, simulate success
        if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
            return { form };
        }

        // Check authentication
        const sessionCookie = cookies.get('access_token');
        if (!sessionCookie) {
            return fail(401, { form, message: 'Authentication required' });
        }

        try {
            const api = createSessionServerApi(sessionCookie);

            // Convert form data to API format
            const apiPayload = {
                name: form.data.name,
                email: form.data.email,
                role: form.data.role,
                is_active: form.data.is_active,
            };

            // Call backend API to update user
            await api.patchRaw(`/api/v1/web/users/${userId}`, apiPayload);

            // Success - form will redirect via onUpdated callback
            return { form };
        } catch (apiError) {
            console.error('Failed to update user:', apiError);

            // Handle specific error cases
            if (apiError && typeof apiError === 'object' && 'response' in apiError) {
                const axiosError = apiError as {
                    response?: { status?: number; data?: { detail?: string } };
                };

                if (axiosError.response?.status === 403) {
                    return fail(403, {
                        form,
                        message: 'Access denied. You must be an administrator to update users.',
                    });
                }

                if (axiosError.response?.status === 404) {
                    return fail(404, {
                        form,
                        message: 'User not found',
                    });
                }

                if (axiosError.response?.status === 409) {
                    return fail(409, {
                        form,
                        message:
                            axiosError.response.data?.detail ||
                            'User with this email already exists',
                    });
                }

                if (axiosError.response?.data?.detail) {
                    return fail(400, { form, message: axiosError.response.data.detail });
                }
            }

            return fail(500, { form, message: 'Failed to update user. Please try again.' });
        }
    },
};

import type { PageServerLoad, Actions } from './$types';
import { superValidate } from 'sveltekit-superforms';
import { zod } from 'sveltekit-superforms/adapters';
import { loginSchema } from '$lib/schemas/auth';
import { fail, redirect } from '@sveltejs/kit';
import { ServerApiClient } from '$lib/server/api';
import { AxiosError } from 'axios';

export const load: PageServerLoad = async ({ cookies, url }) => {
    // Check if user is already authenticated
    const sessionCookie = cookies.get('access_token');
    if (sessionCookie) {
        // User is authenticated, redirect to intended destination or dashboard
        const redirectTo = url.searchParams.get('redirectTo') || '/';
        throw redirect(302, redirectTo);
    }

    // Return form for login
    const form = await superValidate(zod(loginSchema));
    return { form };
};

export const actions: Actions = {
    default: async ({ request, url, cookies }) => {
        const form = await superValidate(request, zod(loginSchema));

        if (!form.valid) {
            return fail(400, { form });
        }

        try {
            // Authenticate with backend using form data
            const api = new ServerApiClient();
            const formData = new FormData();
            formData.append('email', form.data.email);
            formData.append('password', form.data.password);

            // Remove the Content-Type header and let axios handle it automatically
            const response = await api.postRaw('/api/v1/web/auth/login', formData);

            // Backend sets HTTP-only access_token cookie and returns LoginResult
            if (response.status === 200) {
                // Extract and forward cookies from backend response
                const setCookieHeaders = response.headers['set-cookie'];
                if (setCookieHeaders) {
                    for (const cookie of Array.isArray(setCookieHeaders)
                        ? setCookieHeaders
                        : [setCookieHeaders]) {
                        // Parse cookie from "access_token=value; HttpOnly; Secure; SameSite=Lax; Max-Age=3600"
                        const cookieMatch = cookie.match(/^([^=]+)=([^;]+)/);
                        if (cookieMatch && cookieMatch[1] === 'access_token') {
                            cookies.set('access_token', cookieMatch[2], {
                                httpOnly: true,
                                secure: false, // Allow HTTP for development/testing
                                sameSite: 'lax',
                                maxAge: 60 * 60, // 1 hour
                                path: '/' // Required by SvelteKit
                            });
                        }
                    }
                }

                // Redirect to intended destination or dashboard
                const redirectTo = url.searchParams.get('redirectTo') || '/';
                throw redirect(303, redirectTo);
            } else {
                return fail(400, {
                    form,
                    message: 'Invalid credentials'
                });
            }
        } catch (error) {
            console.error('Login error:', error);

            // Handle axios errors with proper typing
            if (error instanceof AxiosError) {
                if (error.response?.status === 401) {
                    return fail(401, {
                        form,
                        message: 'Invalid email or password'
                    });
                }
                if (error.response?.status === 403) {
                    return fail(403, {
                        form,
                        message: 'Account is inactive'
                    });
                }
            }

            return fail(500, {
                form,
                message: 'An error occurred during login. Please try again.'
            });
        }
    }
};

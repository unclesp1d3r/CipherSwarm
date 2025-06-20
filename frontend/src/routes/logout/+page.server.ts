import type { PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ cookies, fetch }) => {
    // Get access token for backend logout call
    const accessToken = cookies.get('access_token');

    // Call backend logout endpoint if we have a token
    if (accessToken) {
        try {
            await fetch('/api/v1/web/auth/logout', {
                method: 'POST',
                headers: {
                    Authorization: `Bearer ${accessToken}`
                }
            });
        } catch (error) {
            // Log error but don't fail logout - we'll clear cookies anyway
            console.error('Backend logout failed:', error);
        }
    }

    // Clear session cookies
    cookies.delete('access_token', { path: '/' });
    cookies.delete('current_project_id', { path: '/' });
    cookies.delete('active_project_id', { path: '/' });

    // Redirect to login page
    throw redirect(302, '/login');
};

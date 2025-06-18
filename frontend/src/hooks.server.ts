import type { Handle } from '@sveltejs/kit';
import { ServerApiClient } from '$lib/server/api';
import { userSessionSchema } from '$lib/schemas/auth';

export const handle: Handle = async ({ event, resolve }) => {
	// Extract session cookie from request (stored as access_token)
	const sessionCookie = event.cookies.get('access_token');
	const currentProjectId = event.cookies.get('current_project_id');

	// Initialize user context
	event.locals.user = null;
	event.locals.session = null;

	// Validate session if cookie exists
	if (sessionCookie) {
		try {
			const api = new ServerApiClient();
			api.setSessionCookie(`access_token=${sessionCookie}`);

			const user = await api.get('/api/v1/web/auth/me', userSessionSchema);

			if (user) {
				// Set user context for load functions
				event.locals.user = {
					...user,
					current_project_id: currentProjectId
						? parseInt(currentProjectId)
						: user.current_project_id,
					is_authenticated: true
				};
				event.locals.session = sessionCookie;
			}
		} catch (error) {
			// Session invalid, clear cookies
			event.cookies.delete('access_token', { path: '/' });
			event.cookies.delete('current_project_id', { path: '/' });
		}
	}

	// Handle the request
	const response = await resolve(event);

	return response;
};

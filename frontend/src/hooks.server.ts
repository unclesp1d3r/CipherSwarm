import type { Handle } from '@sveltejs/kit';
import { ServerApiClient } from '$lib/server/api';
import { contextResponseSchema, type ContextResponse, type UserSession } from '$lib/schemas/auth';

/**
 * Transform ContextResponse from backend into UserSession format for frontend
 */
function transformContextToUserSession(
	context: ContextResponse,
	currentProjectId?: number
): UserSession {
	return {
		id: context.user.id,
		email: context.user.email,
		name: context.user.name,
		role: context.user.role as 'admin' | 'project_admin' | 'user', // Cast to enum
		projects: context.available_projects.map((project) => ({
			id: project.id,
			name: project.name,
			role: context.user.role as 'admin' | 'project_admin' | 'user' // Use user's global role for now
		})),
		current_project_id: currentProjectId || context.active_project?.id,
		is_authenticated: true
	};
}

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

			// Call /context endpoint instead of /me to get user + project info
			const context = await api.get('/api/v1/web/auth/context', contextResponseSchema);

			if (context) {
				// Transform ContextResponse to UserSession format
				const user = transformContextToUserSession(
					context,
					currentProjectId ? parseInt(currentProjectId) : undefined
				);

				// Set user context for load functions
				event.locals.user = user;
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

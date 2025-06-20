import type { Handle, HandleFetch } from '@sveltejs/kit';
import { redirect } from '@sveltejs/kit';
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

/**
 * Attempt to refresh JWT token using auto-refresh endpoint
 */
async function attemptTokenRefresh(api: ServerApiClient): Promise<string | null> {
	try {
		// Call refresh endpoint with auto_refresh=true for automatic refresh
		const response = await api.postRaw('/api/v1/web/auth/refresh', { auto_refresh: true });

		// Extract new token from Set-Cookie header if present
		const setCookieHeader = response.headers['set-cookie'];
		if (setCookieHeader && Array.isArray(setCookieHeader)) {
			for (const cookie of setCookieHeader) {
				if (cookie.startsWith('access_token=')) {
					const tokenMatch = cookie.match(/access_token=([^;]+)/);
					if (tokenMatch) {
						return tokenMatch[1];
					}
				}
			}
		}

		// If no new token in headers, the existing token is still valid
		return null; // Indicates no refresh was needed
	} catch (error) {
		console.error('[Auth] Token refresh failed:', error);
		return null;
	}
}

/**
 * Check if we're in a test environment
 */
function isTestEnvironment(): boolean {
	return (
		process.env.NODE_ENV === 'test' ||
		process.env.PLAYWRIGHT_TEST === 'true' ||
		!!process.env.CI
	);
}

/**
 * Check if the current route should bypass authentication
 */
function isPublicRoute(pathname: string): boolean {
	const publicRoutes = ['/login', '/api-info'];
	return publicRoutes.some((route) => pathname === route || pathname.startsWith(route + '/'));
}

export const handle: Handle = async ({ event, resolve }) => {
	// Skip authentication for test environments and public routes
	if (isTestEnvironment() || isPublicRoute(event.url.pathname)) {
		return resolve(event);
	}

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

			// Call /context endpoint to get user + project info
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
		} catch (error: unknown) {
			// Handle different types of authentication errors
			if ((error as { status?: number })?.status === 401) {
				// Token is expired or invalid, try to refresh
				const api = new ServerApiClient();
				api.setSessionCookie(`access_token=${sessionCookie}`);

				const refreshedToken = await attemptTokenRefresh(api);

				if (refreshedToken) {
					// Refresh successful, update cookie and try again
					event.cookies.set('access_token', refreshedToken, {
						path: '/',
						httpOnly: true,
						secure: process.env.NODE_ENV === 'production',
						sameSite: 'lax',
						maxAge: 60 * 60 // 1 hour
					});

					// Retry context call with new token
					try {
						api.setSessionCookie(`access_token=${refreshedToken}`);
						const context = await api.get(
							'/api/v1/web/auth/context',
							contextResponseSchema
						);

						if (context) {
							const user = transformContextToUserSession(
								context,
								currentProjectId ? parseInt(currentProjectId) : undefined
							);
							event.locals.user = user;
							event.locals.session = refreshedToken;
						}
					} catch (retryError) {
						// Even after refresh, context call failed - clear cookies and redirect
						console.error(
							'[Auth] Context call failed after token refresh:',
							retryError
						);
						event.cookies.delete('access_token', { path: '/' });
						event.cookies.delete('current_project_id', { path: '/' });
						const redirectUrl = `/login?redirectTo=${encodeURIComponent(event.url.pathname + event.url.search)}`;
						throw redirect(302, redirectUrl);
					}
				} else {
					// Refresh failed - clear cookies and redirect to login
					console.log('[Auth] Token refresh failed, redirecting to login');
					event.cookies.delete('access_token', { path: '/' });
					event.cookies.delete('current_project_id', { path: '/' });
					const redirectUrl = `/login?redirectTo=${encodeURIComponent(event.url.pathname + event.url.search)}`;
					throw redirect(302, redirectUrl);
				}
			} else {
				// Other errors (network, server issues) - clear invalid session
				console.error('[Auth] Session validation error:', error);
				event.cookies.delete('access_token', { path: '/' });
				event.cookies.delete('current_project_id', { path: '/' });
				const redirectUrl = `/login?redirectTo=${encodeURIComponent(event.url.pathname + event.url.search)}`;
				throw redirect(302, redirectUrl);
			}
		}
	} else {
		// No session cookie - redirect to login for protected routes
		console.log('[Auth] No session cookie found, redirecting to login');
		const redirectUrl = `/login?redirectTo=${encodeURIComponent(event.url.pathname + event.url.search)}`;
		throw redirect(302, redirectUrl);
	}

	// Handle the request
	const response = await resolve(event);

	return response;
};

/**
 * Handle server-side fetch requests - proxy API calls to backend
 */
export const handleFetch: HandleFetch = async ({ request, fetch }) => {
	const url = new URL(request.url);

	// If this is an API request, proxy it to the backend
	if (url.pathname.startsWith('/api/')) {
		// Get backend URL from environment, default to localhost for development
		const backendUrl = process.env.API_BASE_URL || 'http://localhost:8000';

		// Create new URL with backend host
		const proxiedUrl = new URL(url.pathname + url.search, backendUrl);

		// Create new request with proxied URL but preserve all other properties
		// Note: duplex option is required when sending a body in Node.js
		const proxiedRequest = new Request(proxiedUrl, {
			method: request.method,
			headers: request.headers,
			body: request.body,
			redirect: 'manual',
			duplex: 'half' // Required for Node.js when body is present
		} as RequestInit);

		return fetch(proxiedRequest);
	}

	// For non-API requests, use the original fetch
	return fetch(request);
};

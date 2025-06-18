import type { LayoutServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load: LayoutServerLoad = async ({ locals, url }) => {
	// Check if user is authenticated
	if (!locals.user || !locals.session) {
		// Store the intended destination for redirect after login
		const redirectTo = url.pathname + url.search;
		throw redirect(302, `/login?redirectTo=${encodeURIComponent(redirectTo)}`);
	}

	// Return user data for protected pages
	return {
		user: locals.user
	};
};

import type { PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load: PageServerLoad = async ({ cookies }) => {
	// Clear session cookies
	cookies.delete('sessionid', { path: '/' });
	cookies.delete('current_project_id', { path: '/' });

	// Redirect to login page
	throw redirect(302, '/login');
};

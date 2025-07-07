import type { LayoutServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';

export const load: LayoutServerLoad = async ({ locals, url }) => {
    // Check if user is authenticated
    if (!locals.user || !locals.session) {
        // Store the intended destination for redirect after login
        const redirectTo = url.pathname + url.search;
        throw redirect(302, `/login?redirectTo=${encodeURIComponent(redirectTo)}`);
    }

    // Return user data and projects for protected pages
    return {
        user: locals.user,
        projects: {
            activeProject: locals.user?.current_project_id
                ? {
                      id: locals.user.current_project_id,
                      name:
                          locals.user.projects?.find(
                              (p) => p.id === locals.user?.current_project_id
                          )?.name || 'Unknown',
                  }
                : null,
            availableProjects:
                locals.user?.projects?.map((p) => ({ id: p.id, name: p.name })) || [],
            contextUser: {
                id: locals.user?.id || '',
                email: locals.user?.email || '',
                name: locals.user?.name || '',
                role: locals.user?.role || 'user',
            },
        },
    };
};

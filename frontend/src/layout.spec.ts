import { projectsStore } from '$lib/stores/projects.svelte';
import { render } from '@testing-library/svelte';
import { describe, expect, it, vi } from 'vitest';
import Layout from './routes/+layout.svelte';

// Mock the page store
vi.mock('$app/stores', () => ({
    page: {
        subscribe: vi.fn((callback) => {
            callback({
                route: { id: '/campaigns/[id]' },
                url: new URL('http://localhost/campaigns/1'),
                params: { id: '1' },
                status: 200,
                error: null,
                data: {},
                form: null,
            });
            return () => {}; // unsubscribe function
        }),
    },
}));

describe('App Layout', () => {
    it('renders Sidebar, Header, and Toast', () => {
        projectsStore.setProjectContext(null, [], {
            id: '1',
            name: 'Test User',
            role: 'user',
            email: 'test@test.com',
        });
        const { getByText, getAllByText, queryByRole, debug } = render(Layout, {});
        // Sidebar links (use getAllByText since breadcrumbs also contain "Dashboard")
        expect(getAllByText('Dashboard')).toHaveLength(2); // Sidebar + breadcrumb
        expect(getByText('Campaigns')).toBeTruthy();
        expect(getByText('Agents')).toBeTruthy();
        // Toast (Sonner) - check for region with aria-label or role
        // Sonner uses a <section> with aria-label="Notifications alt+T"
        expect(queryByRole('region', { name: /Notifications/ })).toBeTruthy();
    });
});

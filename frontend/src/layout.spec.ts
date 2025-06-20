import { render } from '@testing-library/svelte';
import Layout from './routes/+layout.svelte';
import { describe, it, expect, vi } from 'vitest';

// Mock the page store
vi.mock('$app/stores', () => ({
    page: {
        subscribe: vi.fn((callback) => {
            callback({
                route: { id: '/dashboard' },
                url: new URL('http://localhost/dashboard'),
                params: {},
                status: 200,
                error: null,
                data: {},
                form: null
            });
            return () => {}; // unsubscribe function
        })
    }
}));

describe('App Layout', () => {
    it('renders Sidebar, Header, and Toast', () => {
        const { getByText, queryByRole } = render(Layout, {});
        // Sidebar links
        expect(getByText('Dashboard')).toBeTruthy();
        expect(getByText('Campaigns')).toBeTruthy();
        expect(getByText('Agents')).toBeTruthy();
        // Toast (Sonner) - check for region with aria-label or role
        // Sonner uses a <section> with aria-label="Notifications alt+T"
        expect(queryByRole('region', { name: /Notifications/ })).toBeTruthy();
    });
});

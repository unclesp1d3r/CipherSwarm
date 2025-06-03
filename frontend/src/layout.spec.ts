import { render } from '@testing-library/svelte';
import Layout from './routes/+layout.svelte';
import { describe, it, expect } from 'vitest';

describe('App Layout', () => {
    it('renders Sidebar, Header, and Toast', () => {
        const { getByText, getByRole } = render(Layout, {});
        // Sidebar links
        expect(getByText('Dashboard')).toBeTruthy();
        expect(getByText('Campaigns')).toBeTruthy();
        expect(getByText('Agents')).toBeTruthy();
        // Header
        expect(getByRole('banner')).toBeTruthy();
        // Toast (Sonner)
        expect(document.querySelector('.toaster')).toBeTruthy();
    });
}); 
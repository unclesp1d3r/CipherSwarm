import { render } from '@testing-library/svelte';
import Layout from './routes/+layout.svelte';
import { describe, it, expect } from 'vitest';

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

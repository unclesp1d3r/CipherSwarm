import { describe, test, expect } from 'vitest';
import '@testing-library/jest-dom/vitest';
import { render, screen } from '@testing-library/svelte';
import Page from './+page.svelte';

describe('/+page.svelte', () => {
    test('renders dashboard cards and campaign overview', () => {
        const { container } = render(Page);
        // Cards
        expect(screen.getByText('Active Agents')).toBeInTheDocument();
        expect(screen.getByText('Running Tasks')).toBeInTheDocument();
        expect(screen.getByText('Recently Cracked')).toBeInTheDocument();
        expect(screen.getByText('Resource Usage')).toBeInTheDocument();
        // Card content
        expect(screen.getByText('0 / 0')).toBeInTheDocument();
        expect(screen.getByText('Online')).toBeInTheDocument();
        expect(screen.getByText('0% Complete')).toBeInTheDocument();
        // Campaign Overview section
        expect(screen.getByRole('heading', { level: 2, name: /Campaign Overview/i })).toBeInTheDocument();
        expect(screen.getByText('Sample Campaign')).toBeInTheDocument();
        // Campaign status text
        expect(screen.getByText('3 attacks / 1 running / ETA 3h')).toBeInTheDocument();
        // Badge in campaign
        expect(screen.getByText('Running')).toBeInTheDocument();
        // Sonner (toast root) should be present
        expect(container.querySelector('[aria-label="Notifications alt+T"]')).toBeTruthy();
    });
});

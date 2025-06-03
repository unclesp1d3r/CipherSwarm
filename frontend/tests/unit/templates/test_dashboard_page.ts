import { describe, test, expect } from 'vitest';
import '@testing-library/jest-dom/vitest';
import { render, screen } from '@testing-library/svelte';
import Page from '../../../src/routes/+page.svelte';

describe('Dashboard Page', () => {
    test('renders Active Agents card', () => {
        render(Page);
        expect(screen.getByText('Active Agents')).toBeInTheDocument();
    });

    test('renders Campaign Overview heading', () => {
        render(Page);
        expect(screen.getByRole('heading', { name: /Campaign Overview/i })).toBeInTheDocument();
    });

    test('renders a campaign name from mock data', () => {
        render(Page);
        expect(screen.getByText('Password Audit')).toBeInTheDocument();
    });
}); 
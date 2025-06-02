import { render, fireEvent } from '@testing-library/svelte';
import AgentsListPage from '../../../src/routes/agents/+page.svelte';
import { describe, it, expect } from 'vitest';

describe('AgentsListPage', () => {
    it('renders table, search input, and register button', () => {
        const { getByText, getByPlaceholderText } = render(AgentsListPage);
        expect(getByText('Agents')).toBeTruthy();
        expect(getByPlaceholderText('Search agents...')).toBeTruthy();
        expect(getByText('Register Agent')).toBeTruthy();
    });

    it('renders agent rows with mock data', () => {
        const { getByText } = render(AgentsListPage);
        expect(getByText('Agent-01')).toBeTruthy();
        expect(getByText('Agent-02')).toBeTruthy();
        expect(getByText('Agent-03')).toBeTruthy();
        expect(getByText('Campaign X')).toBeTruthy();
        expect(getByText('Idle')).toBeTruthy();
        expect(getByText('55 MH/s')).toBeTruthy();
    });

    it('filters agents by search input', async () => {
        const { getByPlaceholderText, queryByText } = render(AgentsListPage);
        const input = getByPlaceholderText('Search agents...');
        await fireEvent.input(input, { target: { value: 'Agent-01' } });
        expect(queryByText('Agent-01')).toBeTruthy();
        expect(queryByText('Agent-02')).toBeNull();
        expect(queryByText('Agent-03')).toBeNull();
    });

    it('shows empty state if no agents match', async () => {
        const { getByPlaceholderText, getByText } = render(AgentsListPage);
        const input = getByPlaceholderText('Search agents...');
        await fireEvent.input(input, { target: { value: 'notfound' } });
        expect(getByText('No agents found.')).toBeTruthy();
    });
}); 
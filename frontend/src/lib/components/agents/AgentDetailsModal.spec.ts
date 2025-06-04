// @vitest-environment happy-dom
import { describe, it, expect, vi } from 'vitest';
import { render, fireEvent, within } from '@testing-library/svelte';
import AgentDetailsModal from './AgentDetailsModal.svelte';
import { writable } from 'svelte/store';
import { isAdmin } from '$lib/stores/session';
import { superForm } from 'sveltekit-superforms';
import { z } from 'zod';
import { zodClient } from 'sveltekit-superforms/adapters';
import TestWrapper from './TestWrapper.svelte';

describe('AgentDetailsModal', () => {
    const agent = {
        id: 1,
        host_name: 'test-agent',
        custom_label: 'Alpha',
        operating_system: 'linux',
        state: 'active',
        temperature: 42,
        utilization: 0.75,
        current_job: 'Test Job',
        current_attempts_sec: 123456,
        avg_attempts_sec: 120000
    };

    it('renders agent details and form fields', () => {
        const { container } = render(TestWrapper, { agent, open: true });
        const body = document.body;
        expect(within(body).getByText('Alpha')).toBeTruthy();
        expect(within(body).getByText('linux')).toBeTruthy();
        expect(within(body).getByText('Status: active')).toBeTruthy();
        expect(within(body).getByText('Temp: 42°C')).toBeTruthy();
        expect(within(body).getByText('Util: 75%')).toBeTruthy();
        expect(within(body).getByText('Current Job:')).toBeTruthy();
        expect(within(body).getByText('Test Job')).toBeTruthy();
        expect(within(body).getByLabelText('GPU')).toBeTruthy();
        expect(within(body).getByLabelText('CPU')).toBeTruthy();
        expect(within(body).getByLabelText('Update Interval (sec)')).toBeTruthy();
    });

    it('shows validation error for invalid update interval', async () => {
        const { container } = render(TestWrapper, { agent, open: true });
        const body = document.body;
        const input = within(body).getByLabelText('Update Interval (sec)');
        await fireEvent.input(input, { target: { value: '0' } });
        expect(within(body).getByText('Must be at least 1 second')).toBeTruthy();
    });

    it('does not show admin controls for non-admin', () => {
        isAdmin.set(false);
        const { container } = render(TestWrapper, { agent, open: true });
        const body = document.body;
        expect(within(body).queryByLabelText('GPU')).toBeNull();
        expect(within(body).queryByLabelText('CPU')).toBeNull();
        expect(within(body).queryByLabelText('Update Interval (sec)')).toBeNull();
        isAdmin.set(true); // reset
    });

    it('renders empty state if no agent', () => {
        const { container } = render(TestWrapper, { agent: null, open: true });
        const body = document.body;
        expect(within(body).getByText('No agent selected.')).toBeTruthy();
    });

    it.skip('emits close event when close button is clicked', async () => {
        const { getByText, component } = render(TestWrapper, { agent, open: true });
        const closeHandler = vi.fn();
        // component.$on('close', closeHandler); // Not supported in Svelte 5 test env
        const closeBtn = getByText('Close');
        await fireEvent.click(closeBtn);
        // expect(closeHandler).toHaveBeenCalled();
    });
}); 
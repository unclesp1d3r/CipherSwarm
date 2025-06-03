import { render, fireEvent } from '@testing-library/svelte';
import AgentDetailsModal from '../../../src/lib/components/agents/AgentDetailsModal.svelte';
import { vi, describe, it, expect } from 'vitest';

const agent = {
    id: 'agent-1',
    custom_label: 'Test Agent',
    host_name: 'host-123',
    status: 'online',
    last_seen: '2024-06-01T12:00:00Z',
    devices: [
        { id: 'dev-1', name: 'GPU 0', type: 'GPU', enabled: true },
        { id: 'dev-2', name: 'CPU 0', type: 'CPU', enabled: false }
    ],
    config: { interval: '30', max_temp: '80' }
};

describe('AgentDetailsModal', () => {
    it('renders agent details in admin mode', () => {
        const { getByText, getByLabelText } = render(AgentDetailsModal, {
            props: { agent, open: true, onClose: vi.fn(), isAdmin: true, onSave: vi.fn(), onToggleDevice: vi.fn() }
        });
        expect(getByText('Test Agent')).toBeTruthy();
        expect(getByText('Online')).toBeTruthy();
        expect(getByLabelText('Display Name')).toHaveValue('Test Agent');
        expect(getByText('Device Toggles')).toBeTruthy();
        expect(getByText('GPU 0 (GPU)')).toBeTruthy();
        expect(getByText('CPU 0 (CPU)')).toBeTruthy();
        expect(getByText('Advanced Config')).toBeTruthy();
        expect(getByLabelText('interval')).toBeTruthy();
        expect(getByLabelText('max_temp')).toBeTruthy();
    });

    it('renders agent details in non-admin mode', () => {
        const { getByText, getByLabelText, queryByText } = render(AgentDetailsModal, {
            props: { agent, open: true, onClose: vi.fn(), isAdmin: false, onSave: vi.fn(), onToggleDevice: vi.fn() }
        });
        expect(getByText('Test Agent')).toBeTruthy();
        expect(getByText('Online')).toBeTruthy();
        expect(getByLabelText('Display Name')).toBeDisabled();
        expect(queryByText('Device Toggles')).toBeNull();
        expect(queryByText('Advanced Config')).toBeNull();
    });

    it('shows empty state if no agent', () => {
        const { getByText } = render(AgentDetailsModal, {
            props: { agent: null, open: true, onClose: vi.fn(), isAdmin: true, onSave: vi.fn(), onToggleDevice: vi.fn() }
        });
        expect(getByText('No agent selected.')).toBeTruthy();
    });

    it('emits save event on form submit', async () => {
        const onClose = vi.fn();
        const onSave = vi.fn();
        const { getByText, component } = render(AgentDetailsModal, {
            props: { agent, open: true, onClose, isAdmin: true, onSave, onToggleDevice: vi.fn() }
        });
        await fireEvent.click(getByText('Save'));
        expect(onSave).toHaveBeenCalled();
        expect(onClose).toHaveBeenCalled();
    });

    it('emits toggleDevice event when device is toggled', async () => {
        const onToggleDevice = vi.fn();
        const { getAllByRole } = render(AgentDetailsModal, {
            props: { agent: { ...agent, devices: [{ ...agent.devices[0], enabled: false }] }, open: true, onClose: vi.fn(), isAdmin: true, onSave: vi.fn(), onToggleDevice }
        });
        const switches = getAllByRole('checkbox');
        await fireEvent.click(switches[0]);
        expect(onToggleDevice).toHaveBeenCalled();
    });

    it('shows error if display name is empty on save', async () => {
        const { getByText, getByLabelText } = render(AgentDetailsModal, {
            props: { agent, open: true, onClose: vi.fn(), isAdmin: true, onSave: vi.fn(), onToggleDevice: vi.fn() }
        });
        const input = getByLabelText('Display Name');
        await fireEvent.input(input, { target: { value: '' } });
        await fireEvent.click(getByText('Save'));
        expect(getByText('Agent must have a display name.')).toBeTruthy();
    });
}); 
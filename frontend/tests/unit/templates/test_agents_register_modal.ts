import { render, fireEvent } from '@testing-library/svelte';
import AgentRegisterModal from '../../../src/lib/components/agents/AgentRegisterModal.svelte';
import { vi, describe, it, expect } from 'vitest';

describe('AgentRegisterModal', () => {
    it('renders registration fields', () => {
        const { getByLabelText, getByText } = render(AgentRegisterModal, {
            props: { open: true, onClose: vi.fn(), onRegister: vi.fn() }
        });
        expect(getByLabelText('Display Name')).toBeTruthy();
        expect(getByLabelText('Host Name')).toBeTruthy();
        expect(getByText('Register')).toBeTruthy();
        expect(getByText('Cancel')).toBeTruthy();
    });

    it('validates required fields', async () => {
        const { getByText } = render(AgentRegisterModal, {
            props: { open: true, onClose: vi.fn(), onRegister: vi.fn() }
        });
        await fireEvent.click(getByText('Register'));
        expect(getByText('Display Name is required.')).toBeTruthy();
    });

    it('shows error if host name is empty', async () => {
        const { getByText, getByLabelText } = render(AgentRegisterModal, {
            props: { open: true, onClose: vi.fn(), onRegister: vi.fn() }
        });
        const displayNameInput = getByLabelText('Display Name');
        await fireEvent.input(displayNameInput, { target: { value: 'Agent X' } });
        await fireEvent.click(getByText('Register'));
        expect(getByText('Host Name is required.')).toBeTruthy();
    });

    it('emits onRegister with form data', async () => {
        const onRegister = vi.fn();
        const { getByText, getByLabelText } = render(AgentRegisterModal, {
            props: { open: true, onClose: vi.fn(), onRegister }
        });
        await fireEvent.input(getByLabelText('Display Name'), { target: { value: 'Agent X' } });
        await fireEvent.input(getByLabelText('Host Name'), { target: { value: 'host-x' } });
        await fireEvent.click(getByText('Register'));
        expect(onRegister).toHaveBeenCalledWith({ display_name: 'Agent X', host_name: 'host-x' });
    });

    it('emits onClose when cancel is clicked', async () => {
        const onClose = vi.fn();
        const { getByText } = render(AgentRegisterModal, {
            props: { open: true, onClose, onRegister: vi.fn() }
        });
        await fireEvent.click(getByText('Cancel'));
        expect(onClose).toHaveBeenCalled();
    });

    it('resets state when closed and reopened', async () => {
        const { getByLabelText, rerender } = render(AgentRegisterModal, {
            props: { open: true, onClose: vi.fn(), onRegister: vi.fn() }
        });
        const displayNameInput = getByLabelText('Display Name');
        await fireEvent.input(displayNameInput, { target: { value: 'Agent X' } });
        await rerender({ open: false, onClose: vi.fn(), onRegister: vi.fn() });
        await rerender({ open: true, onClose: vi.fn(), onRegister: vi.fn() });
        expect((displayNameInput as HTMLInputElement).value).toBe('');
    });
}); 
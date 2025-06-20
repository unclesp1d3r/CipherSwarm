import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import AttackEditWarning from './AttackEditWarning.svelte';

describe('AttackEditWarning', () => {
    const defaultProps = {
        attackName: 'Test Attack'
    };

    it('renders warning message with attack name', () => {
        render(AttackEditWarning, {
            props: defaultProps
        });

        expect(screen.getByText(/Warning:/)).toBeInTheDocument();
        expect(screen.getByText(/Test Attack/)).toBeInTheDocument();
        expect(screen.getByText(/currently running or has been exhausted/)).toBeInTheDocument();
    });

    it('renders confirm and cancel buttons', () => {
        render(AttackEditWarning, {
            props: defaultProps
        });

        expect(screen.getByRole('button', { name: /Continue Anyway/ })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Cancel/ })).toBeInTheDocument();
    });

    it('dispatches confirm event when confirm button is clicked', async () => {
        const mockHandler = vi.fn();
        const component = render(AttackEditWarning, {
            props: {
                ...defaultProps,
                onconfirm: mockHandler
            }
        });

        const confirmButton = screen.getByRole('button', { name: /Continue Anyway/ });
        await fireEvent.click(confirmButton);

        expect(mockHandler).toHaveBeenCalledTimes(1);
    });

    it('dispatches cancel event when cancel button is clicked', async () => {
        const mockHandler = vi.fn();
        const component = render(AttackEditWarning, {
            props: {
                ...defaultProps,
                oncancel: mockHandler
            }
        });

        const cancelButton = screen.getByRole('button', { name: /Cancel/ });
        await fireEvent.click(cancelButton);

        expect(mockHandler).toHaveBeenCalledTimes(1);
    });

    it('shows confirming state when isConfirming is true', () => {
        render(AttackEditWarning, {
            props: {
                ...defaultProps,
                isConfirming: true
            }
        });

        expect(screen.getByRole('button', { name: /Processing.../ })).toBeInTheDocument();
        expect(screen.getByRole('button', { name: /Processing.../ })).toBeDisabled();
        expect(screen.getByRole('button', { name: /Cancel/ })).toBeEnabled();
    });

    it('disables buttons when isConfirming is true', () => {
        render(AttackEditWarning, {
            props: {
                ...defaultProps,
                isConfirming: true
            }
        });

        const confirmButton = screen.getByRole('button', { name: /Processing.../ });
        const cancelButton = screen.getByRole('button', { name: /Cancel/ });

        expect(confirmButton).toBeDisabled();
        expect(cancelButton).toBeEnabled();
    });

    it('handles different attack names', () => {
        render(AttackEditWarning, {
            props: {
                attackName: 'Dictionary Attack #1'
            }
        });

        expect(screen.getByText(/Dictionary Attack #1/)).toBeInTheDocument();
    });

    it('has proper accessibility attributes', () => {
        render(AttackEditWarning, {
            props: defaultProps
        });

        // Check that the alert has proper role
        const alert = screen.getByRole('alert');
        expect(alert).toBeInTheDocument();
    });
});

import { render, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import AttackTableBody from './AttackTableBody.svelte';

// Mock fetch
global.fetch = vi.fn();

const mockAttacks = [
    {
        id: 'attack-1',
        name: 'Dictionary Attack',
        type_label: 'Dictionary',
        length_range: '1 → 8',
        settings_summary: 'rockyou.txt + best64.rule',
        keyspace: 1000000,
        complexity_score: 3,
        comment: 'Test attack',
        type: 'dictionary',
        type_badge: {
            color: 'bg-blue-500',
            label: 'Dictionary',
        },
    },
    {
        id: 'attack-2',
        name: 'Mask Attack',
        type_label: 'Mask',
        length_range: '8',
        settings_summary: '?u?l?l?l?d?d?d?d',
        keyspace: 456789123,
        complexity_score: 4,
        type: 'mask',
        type_badge: {
            color: 'bg-purple-500',
            label: 'Mask',
        },
    },
];

describe('AttackTableBody', () => {
    beforeEach(() => {
        vi.resetAllMocks();
    });

    it('renders attack table rows', () => {
        const { getByText, getAllByText } = render(AttackTableBody, {
            props: {
                attacks: mockAttacks,
            },
        });

        expect(getAllByText('Dictionary')).toHaveLength(2); // Badge and type_label
        expect(getByText('1 → 8')).toBeInTheDocument();
        expect(getByText('rockyou.txt + best64.rule')).toBeInTheDocument();
        expect(getByText('1,000,000')).toBeInTheDocument();
        expect(getByText('Test attack')).toBeInTheDocument();

        expect(getAllByText('Mask')).toHaveLength(2); // Badge and type_label
        expect(getByText('?u?l?l?l?d?d?d?d')).toBeInTheDocument();
        expect(getByText('456,789,123')).toBeInTheDocument();
    });

    it('handles missing optional fields', () => {
        const attacksWithMissingFields = [
            {
                id: 'attack-3',
                name: 'Minimal Attack',
                type_label: 'Brute Force',
                settings_summary: 'Basic settings',
            },
        ];

        const { getByText, getAllByText } = render(AttackTableBody, {
            props: {
                attacks: attacksWithMissingFields,
            },
        });

        // The name field is not displayed in the component, only the badge label
        expect(getByText('Brute Force')).toBeInTheDocument();
        expect(getByText('Basic settings')).toBeInTheDocument();

        // Should show '-' for missing fields
        const dashElements = getAllByText('-');
        expect(dashElements.length).toBeGreaterThan(0);
    });

    it('renders dropdown menu button', () => {
        const { getByLabelText } = render(AttackTableBody, {
            props: {
                attacks: [mockAttacks[0]],
            },
        });

        const menuButton = getByLabelText('Open menu for Dictionary Attack');
        expect(menuButton).toBeInTheDocument();
        expect(menuButton).toHaveAttribute('aria-haspopup', 'menu');
    });

    it('has callback props for actions', () => {
        const onMoveAttack = vi.fn();
        const onEditAttack = vi.fn();
        const onDeleteAttack = vi.fn();
        const onDuplicateAttack = vi.fn();

        const { getByLabelText } = render(AttackTableBody, {
            props: {
                attacks: [mockAttacks[0]],
                onMoveAttack,
                onEditAttack,
                onDeleteAttack,
                onDuplicateAttack,
            },
        });

        // Just verify the component renders with callbacks
        const menuButton = getByLabelText('Open menu for Dictionary Attack');
        expect(menuButton).toBeInTheDocument();
    });

    it('renders with all callback props', () => {
        const onEditAttack = vi.fn();
        const onDeleteAttack = vi.fn();
        const onDuplicateAttack = vi.fn();
        const onMoveAttack = vi.fn();

        const { getByText, getAllByText } = render(AttackTableBody, {
            props: {
                attacks: [mockAttacks[0]],
                onEditAttack,
                onDeleteAttack,
                onDuplicateAttack,
                onMoveAttack,
            },
        });

        // Verify the component renders the attack data
        expect(getAllByText('Dictionary')).toHaveLength(2); // Badge and type_label
        expect(getByText('rockyou.txt + best64.rule')).toBeInTheDocument();
    });

    it('renders dropdown menu trigger button', () => {
        const { getByLabelText } = render(AttackTableBody, {
            props: {
                attacks: [mockAttacks[0]],
            },
        });

        const menuButton = getByLabelText('Open menu for Dictionary Attack');
        expect(menuButton).toBeInTheDocument();
        expect(menuButton.tagName).toBe('BUTTON');
    });

    it('formats numbers correctly', () => {
        const attackWithLargeNumbers = [
            {
                id: 'attack-large',
                name: 'Large Attack',
                type_label: 'Mask',
                settings_summary: 'Large keyspace',
                keyspace: 1234567890123,
            },
        ];

        const { getByText } = render(AttackTableBody, {
            props: {
                attacks: attackWithLargeNumbers,
            },
        });

        expect(getByText('1,234,567,890,123')).toBeInTheDocument();
    });
});

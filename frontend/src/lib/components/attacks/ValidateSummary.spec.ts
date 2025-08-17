import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import ValidateSummary from './ValidateSummary.svelte';

describe('ValidateSummary', () => {
    it('renders validation summary with all data', () => {
        const { getByText } = render(ValidateSummary, {
            props: {
                mode: 'dictionary',
                keyspace: 1000000,
                complexity: 'Medium',
                complexityScore: 3,
            },
        });

        expect(getByText('Attack Validated')).toBeInTheDocument();
        expect(getByText('Mode:')).toBeInTheDocument();
        expect(getByText('dictionary')).toBeInTheDocument();
        expect(getByText('Keyspace:')).toBeInTheDocument();
        expect(getByText('1,000,000')).toBeInTheDocument();
        expect(getByText('Complexity:')).toBeInTheDocument();
        expect(getByText('Medium')).toBeInTheDocument();
        expect(getByText('Complexity Score:')).toBeInTheDocument();
        expect(getByText('3')).toBeInTheDocument();
    });

    it('renders with minimal data', () => {
        const { getByText, queryByText } = render(ValidateSummary, {
            props: {
                mode: 'mask',
            },
        });

        expect(getByText('Attack Validated')).toBeInTheDocument();
        expect(getByText('Mode:')).toBeInTheDocument();
        expect(getByText('mask')).toBeInTheDocument();
        expect(getByText('Keyspace:')).toBeInTheDocument();
        expect(getByText('N/A')).toBeInTheDocument();
        expect(queryByText('Complexity:')).not.toBeInTheDocument();
        expect(queryByText('Complexity Score:')).not.toBeInTheDocument();
    });

    it('handles string keyspace values', () => {
        const { getByText } = render(ValidateSummary, {
            props: {
                mode: 'brute_force',
                keyspace: '5000000',
            },
        });

        expect(getByText('5,000,000')).toBeInTheDocument();
    });

    it('handles undefined keyspace', () => {
        const { getByText } = render(ValidateSummary, {
            props: {
                mode: 'hybrid',
                keyspace: undefined,
            },
        });

        expect(getByText('N/A')).toBeInTheDocument();
    });

    it('renders complexity field when provided', () => {
        const { getByText, queryByText } = render(ValidateSummary, {
            props: {
                mode: 'dictionary',
                complexity: 'High',
            },
        });

        expect(getByText('Complexity:')).toBeInTheDocument();
        expect(getByText('High')).toBeInTheDocument();
        expect(queryByText('Complexity Score:')).not.toBeInTheDocument();
    });

    it('renders complexity score field when provided', () => {
        const { getByText, queryByText } = render(ValidateSummary, {
            props: {
                mode: 'dictionary',
                complexityScore: 4,
            },
        });

        expect(queryByText('Complexity:')).not.toBeInTheDocument();
        expect(getByText('Complexity Score:')).toBeInTheDocument();
        expect(getByText('4')).toBeInTheDocument();
    });

    it('formats large keyspace numbers', () => {
        const { getByText } = render(ValidateSummary, {
            props: {
                mode: 'mask',
                keyspace: 1234567890123,
            },
        });

        expect(getByText('1,234,567,890,123')).toBeInTheDocument();
    });
});

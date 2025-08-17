import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import BruteForcePreview from './BruteForcePreview.svelte';

describe('BruteForcePreview', () => {
    it('renders charset and mask preview', () => {
        const { getByDisplayValue, getByText } = render(BruteForcePreview, {
            props: {
                customCharset: 'abcdefghijklmnopqrstuvwxyz0123456789',
                mask: '?1?1?1?1?1?1',
            },
        });

        expect(getByText('Charset Preview (?1)')).toBeInTheDocument();
        expect(getByText('Generated Mask')).toBeInTheDocument();
        expect(getByDisplayValue('abcdefghijklmnopqrstuvwxyz0123456789')).toBeInTheDocument();
        expect(getByDisplayValue('?1?1?1?1?1?1')).toBeInTheDocument();
    });

    it('renders with empty values', () => {
        const { getAllByDisplayValue } = render(BruteForcePreview, {
            props: {
                customCharset: '',
                mask: '',
            },
        });

        const emptyInputs = getAllByDisplayValue('');
        expect(emptyInputs).toHaveLength(2); // charset and mask inputs
    });

    it('has readonly inputs', () => {
        const { container } = render(BruteForcePreview, {
            props: {
                customCharset: 'test',
                mask: 'test',
            },
        });

        const inputs = container.querySelectorAll('input');
        inputs.forEach((input) => {
            expect(input).toHaveAttribute('readonly');
        });
    });
});

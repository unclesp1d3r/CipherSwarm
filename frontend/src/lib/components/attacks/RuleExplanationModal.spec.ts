import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import RuleExplanationModal from './RuleExplanationModal.svelte';

describe('RuleExplanationModal', () => {
    it('renders modal when open is true', () => {
        render(RuleExplanationModal, { props: { open: true } });

        expect(screen.getByText('Hashcat Rule Syntax - Common Rules')).toBeInTheDocument();
        expect(screen.getByRole('table')).toBeInTheDocument();
    });

    it('displays rule explanations in table format', () => {
        render(RuleExplanationModal, { props: { open: true } });

        // Check for table headers
        expect(screen.getByText('Rule')).toBeInTheDocument();
        expect(screen.getByText('Explanation')).toBeInTheDocument();

        // Check for some specific rules
        expect(screen.getByText('l')).toBeInTheDocument();
        expect(screen.getByText('Lowercase all letters')).toBeInTheDocument();
        expect(screen.getByText('u')).toBeInTheDocument();
        expect(screen.getByText('Uppercase all letters')).toBeInTheDocument();
    });

    it('includes common hashcat rules', () => {
        render(RuleExplanationModal, { props: { open: true } });

        // Test a few key rules are present
        const expectedRules = [
            { rule: ':', desc: 'Do nothing (no-op)' },
            { rule: 'r', desc: 'Reverse the word' },
            { rule: 'd', desc: 'Duplicate the word' },
            { rule: '$X', desc: 'Append character X' },
            { rule: '^X', desc: 'Prepend character X' }
        ];

        expectedRules.forEach(({ rule, desc }) => {
            expect(screen.getByText(rule)).toBeInTheDocument();
            expect(screen.getByText(desc)).toBeInTheDocument();
        });
    });

    it('has proper table structure', () => {
        render(RuleExplanationModal, { props: { open: true } });

        const table = screen.getByRole('table');
        expect(table).toBeInTheDocument();

        // Should have header row plus data rows
        const rows = screen.getAllByRole('row');
        expect(rows.length).toBeGreaterThan(1); // Header + data rows
    });
});

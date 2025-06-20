import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import PerformanceSummary from './PerformanceSummary.svelte';

describe('PerformanceSummary', () => {
    it('renders performance summary with all data', () => {
        const { getByText } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                totalHashes: 1000000,
                hashesDone: 500000,
                agentCount: 3,
                hashesPerSec: 1500.75,
                progress: 50.5,
                eta: 3661 // 1h 1m 1s
            }
        });

        expect(getByText('Performance Summary')).toBeInTheDocument();
        expect(getByText('Attack: Test Attack')).toBeInTheDocument();
        expect(getByText('1,000,000')).toBeInTheDocument();
        expect(getByText('500,000')).toBeInTheDocument();
        expect(getByText('3')).toBeInTheDocument();
        expect(getByText('1501 H/s')).toBeInTheDocument();
        expect(getByText('50.5%')).toBeInTheDocument();
        expect(getByText('1h 1m 1s')).toBeInTheDocument();
    });

    it('renders with default values', () => {
        const { getByText, getAllByText } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack'
            }
        });

        expect(getByText('Performance Summary')).toBeInTheDocument();
        expect(getByText('Attack: Test Attack')).toBeInTheDocument();
        expect(getAllByText('N/A')).toHaveLength(4); // totalHashes, speed, progress, eta
        expect(getAllByText('0')).toHaveLength(2); // hashesDone and agentCount
    });

    it('handles undefined values correctly', () => {
        const { getAllByText } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                totalHashes: undefined,
                hashesPerSec: undefined,
                progress: undefined,
                eta: undefined
            }
        });

        // Should show N/A for undefined values
        const naElements = getAllByText('N/A');
        expect(naElements).toHaveLength(4); // totalHashes, speed, progress, eta
    });

    it('formats ETA correctly for different durations', () => {
        // Test 1 hour
        const { getByText: getByText1 } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                eta: 3600 // 1 hour
            }
        });
        expect(getByText1('1h 0m 0s')).toBeInTheDocument();

        // Test 1 minute 30 seconds
        const { getByText: getByText2 } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                eta: 90 // 1 minute 30 seconds
            }
        });
        expect(getByText2('0h 1m 30s')).toBeInTheDocument();

        // Test 45 seconds
        const { getByText: getByText3 } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                eta: 45 // 45 seconds
            }
        });
        expect(getByText3('0h 0m 45s')).toBeInTheDocument();
    });

    it('formats large numbers with commas', () => {
        const { getByText } = render(PerformanceSummary, {
            props: {
                attackName: 'Test Attack',
                totalHashes: 1234567890,
                hashesDone: 987654321
            }
        });

        expect(getByText('1,234,567,890')).toBeInTheDocument();
        expect(getByText('987,654,321')).toBeInTheDocument();
    });
});

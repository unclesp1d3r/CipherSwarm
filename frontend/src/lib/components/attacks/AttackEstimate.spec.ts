import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import AttackEstimate from './AttackEstimate.svelte';

describe('AttackEstimate', () => {
	it('renders keyspace and complexity score', () => {
		const { getByText } = render(AttackEstimate, {
			props: {
				keyspace: 1000000,
				complexityScore: 3
			}
		});

		expect(getByText('Keyspace Estimate:')).toBeInTheDocument();
		expect(getByText('1,000,000')).toBeInTheDocument();
		expect(getByText('Complexity Score:')).toBeInTheDocument();
		expect(getByText('3')).toBeInTheDocument();
	});

	it('renders with default values', () => {
		const { getByText } = render(AttackEstimate);

		expect(getByText('Keyspace Estimate:')).toBeInTheDocument();
		expect(getByText('0')).toBeInTheDocument();
		expect(getByText('Complexity Score:')).toBeInTheDocument();
		expect(getByText('1')).toBeInTheDocument();
	});

	it('handles string keyspace values', () => {
		const { getByText } = render(AttackEstimate, {
			props: {
				keyspace: '5000000',
				complexityScore: 4
			}
		});

		expect(getByText('5,000,000')).toBeInTheDocument();
		expect(getByText('4')).toBeInTheDocument();
	});

	it('handles invalid keyspace values', () => {
		const { getByText } = render(AttackEstimate, {
			props: {
				keyspace: 'invalid',
				complexityScore: 2
			}
		});

		expect(getByText('0')).toBeInTheDocument();
		expect(getByText('2')).toBeInTheDocument();
	});

	it('formats large numbers correctly', () => {
		const { getByText } = render(AttackEstimate, {
			props: {
				keyspace: 1234567890123,
				complexityScore: 5
			}
		});

		expect(getByText('1,234,567,890,123')).toBeInTheDocument();
		expect(getByText('5')).toBeInTheDocument();
	});
});

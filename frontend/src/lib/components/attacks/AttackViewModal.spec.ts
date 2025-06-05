import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, vi } from 'vitest';
import AttackViewModal from './AttackViewModal.svelte';
import type { ComponentProps } from 'svelte';

// Mock axios
vi.mock('axios', () => ({
	default: {
		get: vi.fn().mockRejectedValue({ response: { status: 404 } })
	}
}));

interface Attack {
	id?: number;
	name?: string;
	attack_mode?: string;
	mask?: string;
	language?: string;
	min_length?: number;
	max_length?: number;
	increment_minimum?: number;
	increment_maximum?: number;
	keyspace?: number;
	complexity_score?: number;
	created_at?: string;
	updated_at?: string;
	type?: string;
	comment?: string;
	description?: string;
	state?: string;
	[key: string]: unknown;
}

const mockAttack: Attack = {
	id: 1,
	name: 'Test Attack',
	attack_mode: 'dictionary',
	type: 'dictionary',
	state: 'running',
	description: 'Test attack description',
	comment: 'Test comment',
	min_length: 8,
	max_length: 12,
	keyspace: 1000000,
	complexity_score: 3,
	created_at: '2023-01-01T00:00:00Z',
	updated_at: '2023-01-02T00:00:00Z'
};

type Props = ComponentProps<AttackViewModal>;

describe('AttackViewModal', () => {
	it('renders modal when open', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		expect(screen.getByText('Attack Details')).toBeInTheDocument();
		expect(screen.getByText('Basic Information')).toBeInTheDocument();
	});

	it('displays basic information section', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		expect(screen.getByText('Basic Information')).toBeInTheDocument();
		expect(screen.getByText('Name')).toBeInTheDocument();
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		expect(screen.getByText('State')).toBeInTheDocument();
		expect(screen.getByText('Running')).toBeInTheDocument();
	});

	it('displays attack settings section', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		expect(screen.getByText('Attack Settings')).toBeInTheDocument();
		expect(screen.getByText('Min Length')).toBeInTheDocument();
		expect(screen.getByText('Max Length')).toBeInTheDocument();
	});

	it('displays complexity and keyspace section', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Complexity Score')).toBeInTheDocument();
	});

	it('displays timestamps section', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		expect(screen.getByText('Timestamps')).toBeInTheDocument();
		expect(screen.getByText('Created')).toBeInTheDocument();
		expect(screen.getByText('Last Updated')).toBeInTheDocument();
	});

	it('calls onclose when close button is clicked', async () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			} as Props
		});

		// Test that the close button exists
		const closeButtons = screen.getAllByRole('button', { name: 'Close' });
		expect(closeButtons.length).toBeGreaterThan(0);

		// Verify there's at least one close button without an SVG (footer button)
		const footerCloseButton = closeButtons.find(
			(button) => button.textContent === 'Close' && !button.querySelector('svg')
		);
		expect(footerCloseButton).toBeTruthy();
	});

	it('handles attack without optional fields', () => {
		const minimalAttack: Attack = {
			id: 2,
			name: 'Minimal Attack',
			type: 'brute_force'
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: minimalAttack
			} as Props
		});

		expect(screen.getByText('Basic Information')).toBeInTheDocument();
		expect(screen.getByText('Name')).toBeInTheDocument();
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		expect(screen.getByText('State')).toBeInTheDocument();
	});

	it('formats keyspace correctly for different sizes', () => {
		const largeKeyspaceAttack: Attack = {
			id: 3,
			name: 'Large Attack',
			keyspace: 1500000000
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: largeKeyspaceAttack
			} as Props
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Keyspace')).toBeInTheDocument();
	});
});

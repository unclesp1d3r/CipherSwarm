import { render, screen } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import AttackViewModal from './AttackViewModal.svelte';
import type { Attack } from '$lib/stores/attacks';

// Mock the stores
vi.mock('$lib/stores/attacks', () => ({
	attacksActions: {
		updateAttackPerformance: vi.fn(),
		loadAttackPerformance: vi.fn()
	},
	createAttackPerformanceStore: vi.fn(() => ({
		subscribe: vi.fn((callback) => {
			callback(null);
			return () => {};
		})
	})),
	createAttackLoadingStore: vi.fn(() => ({
		subscribe: vi.fn((callback) => {
			callback(false);
			return () => {};
		})
	})),
	createAttackErrorStore: vi.fn(() => ({
		subscribe: vi.fn((callback) => {
			callback(null);
			return () => {};
		})
	}))
}));

// Mock browser environment
vi.mock('$app/environment', () => ({
	browser: true
}));

describe('AttackViewModal', () => {
	const mockAttack: Attack = {
		id: 1,
		name: 'Test Attack',
		attack_mode: 'dictionary',
		type: 'dictionary',
		state: 'running',
		created_at: '2023-01-01T00:00:00Z',
		updated_at: '2023-01-01T12:00:00Z',
		comment: 'Test attack description',
		word_list_name: 'rockyou.txt',
		rule_list_name: 'best64.rule',
		min_length: 8,
		max_length: 12,
		keyspace: 1000000,
		hash_type_id: 1000
	};

	beforeEach(() => {
		vi.clearAllMocks();
	});

	it('renders modal when open is true', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			}
		});

		expect(screen.getByText('Attack Details')).toBeInTheDocument();
		expect(screen.getByText('Attack: Test Attack')).toBeInTheDocument();
	});

	it('does not render modal content when open is false', () => {
		render(AttackViewModal, {
			props: {
				open: false,
				attack: mockAttack
			}
		});

		expect(screen.queryByText('Attack Details: Test Attack')).not.toBeInTheDocument();
	});

	it('displays basic information section', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			}
		});

		expect(screen.getByText('Basic Information')).toBeInTheDocument();
		expect(screen.getByText('Attack Name')).toBeInTheDocument();
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		expect(screen.getByText('State')).toBeInTheDocument();
		expect(screen.getByText('Created')).toBeInTheDocument();
	});

	it('displays word list and rule list information', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			}
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Word List')).toBeInTheDocument();
		expect(screen.getByText('Rule List')).toBeInTheDocument();
	});

	it('displays keyspace and hash type information', () => {
		const attackWithHashType = {
			...mockAttack,
			hash_type_id: 1000
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: attackWithHashType
			}
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Hash Type ID')).toBeInTheDocument();
	});

	it('handles attack without optional fields', () => {
		const minimalAttack: Attack = {
			id: 2,
			name: 'Minimal Attack',
			state: 'pending'
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: minimalAttack
			}
		});

		expect(screen.getByText('Basic Information')).toBeInTheDocument();
		expect(screen.getByText('Attack Name')).toBeInTheDocument();
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		expect(screen.getByText('State')).toBeInTheDocument();
	});

	it('formats keyspace correctly for different sizes', () => {
		const largeAttack = {
			...mockAttack,
			name: 'Large Attack',
			keyspace: 1500000000000 // 1.5T
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: largeAttack
			}
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Keyspace')).toBeInTheDocument();
	});

	it('displays mask information for mask attacks', () => {
		const maskAttack = {
			...mockAttack,
			attack_mode: 'mask',
			mask: '?d?d?d?d'
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: maskAttack
			}
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Mask')).toBeInTheDocument();
	});

	it('displays custom charset information when available', () => {
		const charsetAttack = {
			...mockAttack,
			custom_charset_1: 'abcdefghijklmnopqrstuvwxyz'
		};

		render(AttackViewModal, {
			props: {
				open: true,
				attack: charsetAttack
			}
		});

		expect(screen.getByText('Complexity & Keyspace')).toBeInTheDocument();
		expect(screen.getByText('Custom Charset 1')).toBeInTheDocument();
	});

	it('shows close button', () => {
		render(AttackViewModal, {
			props: {
				open: true,
				attack: mockAttack
			}
		});

		const closeButtons = screen.getAllByRole('button', { name: /close/i });
		const footerCloseButton = closeButtons.find(
			(button) => button.textContent?.trim() === 'Close'
		);
		expect(footerCloseButton).toBeInTheDocument();
	});
});

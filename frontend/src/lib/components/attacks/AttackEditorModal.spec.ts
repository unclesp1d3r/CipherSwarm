import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import { tick } from 'svelte';
import AttackEditorModal from './AttackEditorModal.svelte';

// Mock axios
vi.mock('axios', () => ({
	default: {
		get: vi.fn().mockResolvedValue({ data: [] }),
		post: vi.fn().mockResolvedValue({
			data: {
				keyspace: 1000000,
				complexity_score: 3,
				estimated_time: '2 hours'
			}
		}),
		put: vi.fn().mockResolvedValue({ data: {} })
	}
}));

describe('AttackEditorModal', () => {
	const mockHandlers = {
		onsuccess: vi.fn(),
		oncancel: vi.fn()
	};

	it('renders with default props', () => {
		render(AttackEditorModal, {
			props: {
				attack: null,
				open: true,
				...mockHandlers
			}
		});

		expect(screen.getByText('Create Attack')).toBeInTheDocument();
		expect(screen.getByPlaceholderText('Enter attack name')).toBeInTheDocument();
	});

	it('renders in edit mode when attack is provided', () => {
		const mockAttack = {
			id: 1,
			name: 'Test Attack',
			type: 'dictionary',
			comment: 'Test comment'
		};

		render(AttackEditorModal, {
			props: {
				attack: mockAttack,
				open: true,
				...mockHandlers
			}
		});

		expect(screen.getByText('Edit Attack')).toBeInTheDocument();
		expect(screen.getByDisplayValue('Test Attack')).toBeInTheDocument();
	});

	it('shows dictionary mode by default', () => {
		render(AttackEditorModal, {
			props: {
				attack: null,
				open: true,
				...mockHandlers
			}
		});

		expect(screen.getByText('Dictionary Mode')).toBeInTheDocument();
		// The wordlist selection may not be visible until form is more complete
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
	});

	it('renders required form elements', () => {
		render(AttackEditorModal, {
			props: {
				attack: null,
				open: true,
				...mockHandlers
			}
		});

		expect(screen.getByText('Name')).toBeInTheDocument();
		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		expect(screen.getByPlaceholderText('Enter attack name')).toBeInTheDocument();
	});

	it('displays cancel and submit buttons', () => {
		render(AttackEditorModal, {
			props: {
				attack: null,
				open: true,
				...mockHandlers
			}
		});

		const cancelButton = screen.getByRole('button', { name: 'Cancel' });
		const submitButton = screen.getByRole('button', { name: 'Add Attack' });

		expect(cancelButton).toBeInTheDocument();
		expect(submitButton).toBeInTheDocument();
	});

	it('renders attack modes section', () => {
		render(AttackEditorModal, {
			props: {
				attack: null,
				open: true,
				...mockHandlers
			}
		});

		expect(screen.getByText('Attack Mode')).toBeInTheDocument();
		// The default select value should be "dictionary"
		expect(screen.getByText('Dictionary Mode')).toBeInTheDocument();
	});
});

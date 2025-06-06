import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import ResourceDetail from './ResourceDetail.svelte';

const mockResource = {
	id: '1',
	file_name: 'test.txt',
	resource_type: 'word_list',
	byte_size: 1024,
	line_count: 100,
	checksum: 'abc123',
	guid: 'guid-123',
	updated_at: '2023-01-01T00:00:00Z'
};

const mockAttacks = [
	{
		id: 'attack-1',
		name: 'Test Attack',
		campaign_id: 'campaign-1',
		state: 'running'
	}
];

describe('ResourceDetail', () => {
	it('renders loading state', () => {
		render(ResourceDetail, {
			props: {
				resource: null,
				attacks: [],
				loading: true,
				error: null
			}
		});

		expect(document.querySelector('.animate-pulse')).toBeTruthy(); // Check for skeleton elements by class
	});

	it('renders error state', () => {
		render(ResourceDetail, {
			props: {
				resource: null,
				attacks: [],
				loading: false,
				error: 'Test error'
			}
		});

		expect(screen.getByText('Test error')).toBeTruthy();
	});

	it('renders resource information', () => {
		render(ResourceDetail, {
			props: {
				resource: mockResource,
				attacks: [],
				loading: false,
				error: null
			}
		});

		expect(screen.getByText('Resource: test.txt')).toBeTruthy();
		expect(screen.getByText('Word List')).toBeTruthy();
		expect(screen.getByText('1 KB')).toBeTruthy();
		expect(screen.getByText('100')).toBeTruthy();
		expect(screen.getByText('abc123')).toBeTruthy();
		expect(screen.getByText('guid-123')).toBeTruthy();
	});

	it('renders linked attacks', () => {
		render(ResourceDetail, {
			props: {
				resource: mockResource,
				attacks: mockAttacks,
				loading: false,
				error: null
			}
		});

		expect(screen.getByText('Linked Attacks')).toBeTruthy();
		expect(screen.getByText('Test Attack')).toBeTruthy();
		expect(screen.getByText('attack-1')).toBeTruthy();
		expect(screen.getByText('campaign-1')).toBeTruthy();
		expect(screen.getByText('running')).toBeTruthy();
	});

	it('renders empty attacks state', () => {
		render(ResourceDetail, {
			props: {
				resource: mockResource,
				attacks: [],
				loading: false,
				error: null
			}
		});

		expect(screen.getByText('No attacks linked to this resource.')).toBeTruthy();
	});

	it('formats file size correctly', () => {
		const largeResource = {
			...mockResource,
			byte_size: 2048000 // 2MB
		};

		render(ResourceDetail, {
			props: {
				resource: largeResource,
				attacks: [],
				loading: false,
				error: null
			}
		});

		expect(screen.getByText('2 MB')).toBeTruthy();
	});

	it('handles null line count', () => {
		const resourceWithoutLines = {
			...mockResource,
			line_count: null
		};

		render(ResourceDetail, {
			props: {
				resource: resourceWithoutLines,
				attacks: [],
				loading: false,
				error: null
			}
		});

		expect(screen.getByText('N/A')).toBeTruthy();
	});
});

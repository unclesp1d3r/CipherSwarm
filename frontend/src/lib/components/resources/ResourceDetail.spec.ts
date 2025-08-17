import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import ResourceDetail from './ResourceDetail.svelte';
import type { ResourceDetailResponse } from '$lib/schemas/resources';
import type { AttackBasic } from '$lib/types/attack';

const mockResource: ResourceDetailResponse = {
    id: '550e8400-e29b-41d4-a716-446655440001',
    file_name: 'test.txt',
    file_label: 'Test File',
    resource_type: 'word_list',
    line_count: 100,
    byte_size: 1024,
    checksum: 'abc123',
    updated_at: '2023-01-01T00:00:00Z',
    line_format: null,
    line_encoding: 'utf-8',
    used_for_modes: ['dictionary'],
    source: 'test',
    project_id: 1,
    unrestricted: false,
    is_uploaded: true,
    tags: ['test'],
    created_at: '2023-01-01T00:00:00Z',
    uploaded_by: 'test-user',
    usage_count: 5,
    last_used: '2023-01-02T00:00:00Z',
};

const mockAttacks: AttackBasic[] = [
    {
        id: 1,
        name: 'Test Attack',
        attack_mode: 'dictionary',
        type_label: 'Dictionary Attack',
        settings_summary: 'Test settings',
    },
];

describe('ResourceDetail', () => {
    it('renders loading state', () => {
        render(ResourceDetail, {
            props: {
                resource: null,
                attacks: [],
                loading: true,
                error: null,
            },
        });

        expect(document.querySelector('.animate-pulse')).toBeTruthy(); // Check for skeleton elements by class
    });

    it('renders error state', () => {
        render(ResourceDetail, {
            props: {
                resource: null,
                attacks: [],
                loading: false,
                error: 'Test error',
            },
        });

        expect(screen.getByText('Test error')).toBeTruthy();
    });

    it('renders resource information', () => {
        render(ResourceDetail, {
            props: {
                resource: mockResource,
                attacks: [],
                loading: false,
                error: null,
            },
        });

        expect(screen.getByText('Resource: test.txt')).toBeTruthy();
        expect(screen.getByText('Word List')).toBeTruthy();
        expect(screen.getByText('1 KB')).toBeTruthy();
        expect(screen.getByText('100')).toBeTruthy();
        expect(screen.getByText('abc123')).toBeTruthy();
        expect(screen.getByText('550e8400-e29b-41d4-a716-446655440001')).toBeTruthy();
    });

    it('renders linked attacks', () => {
        render(ResourceDetail, {
            props: {
                resource: mockResource,
                attacks: mockAttacks,
                loading: false,
                error: null,
            },
        });

        expect(screen.getByText('Linked Attacks')).toBeTruthy();
        expect(screen.getByText('Test Attack')).toBeTruthy();
        expect(screen.getByText('1')).toBeTruthy();
    });

    it('renders empty attacks state', () => {
        render(ResourceDetail, {
            props: {
                resource: mockResource,
                attacks: [],
                loading: false,
                error: null,
            },
        });

        expect(screen.getByText('No attacks linked to this resource.')).toBeTruthy();
    });

    it('formats file size correctly', () => {
        const largeResource: ResourceDetailResponse = {
            ...mockResource,
            byte_size: 2048000, // 2MB
        };

        render(ResourceDetail, {
            props: {
                resource: largeResource,
                attacks: [],
                loading: false,
                error: null,
            },
        });

        expect(screen.getByText('2 MB')).toBeTruthy();
    });

    it('handles null line count', () => {
        const resourceWithoutLines: ResourceDetailResponse = {
            ...mockResource,
            line_count: null,
        };

        render(ResourceDetail, {
            props: {
                resource: resourceWithoutLines,
                attacks: [],
                loading: false,
                error: null,
            },
        });

        expect(screen.getByText('N/A')).toBeTruthy();
    });
});

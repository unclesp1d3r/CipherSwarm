import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import ProjectInfo from './ProjectInfo.svelte';
import type { Project } from '$lib/types/project.js';

describe('ProjectInfo', () => {
	const mockProject: Project = {
		id: 1,
		name: 'Test Project',
		description: 'A test project description',
		private: false,
		archived_at: null,
		notes: 'Some project notes',
		users: ['user1-uuid', 'user2-uuid'],
		created_at: '2024-01-01T00:00:00Z',
		updated_at: '2024-01-02T00:00:00Z'
	};

	it('renders project information correctly', () => {
		render(ProjectInfo, { props: { project: mockProject } });

		expect(screen.getByText('Project: Test Project')).toBeInTheDocument();
		expect(screen.getByText('A test project description')).toBeInTheDocument();
		expect(screen.getByText('Some project notes')).toBeInTheDocument();
		expect(screen.getByText('2 users')).toBeInTheDocument();
		expect(screen.getByText('1')).toBeInTheDocument(); // ID
	});

	it('handles null/empty values correctly', () => {
		const projectWithNulls: Project = {
			...mockProject,
			description: null,
			notes: null,
			archived_at: null,
			users: []
		};

		render(ProjectInfo, { props: { project: projectWithNulls } });

		expect(screen.getByText('—')).toBeInTheDocument(); // Description placeholder
		expect(screen.getByText('0 users')).toBeInTheDocument();
		expect(screen.queryByText('Notes')).not.toBeInTheDocument(); // Notes section should not render
	});

	it('displays private badge for private projects', () => {
		const privateProject: Project = {
			...mockProject,
			private: true
		};

		render(ProjectInfo, { props: { project: privateProject } });

		expect(screen.getByText('Private')).toBeInTheDocument();
	});

	it('displays archived badge and date for archived projects', () => {
		const archivedProject: Project = {
			...mockProject,
			archived_at: '2024-01-03T00:00:00Z'
		};

		render(ProjectInfo, { props: { project: archivedProject } });

		expect(screen.getByText('Archived')).toBeInTheDocument();
		expect(screen.getByText('Archived At')).toBeInTheDocument();
	});

	it('formats dates correctly', () => {
		render(ProjectInfo, { props: { project: mockProject } });

		// Check that dates are formatted (exact format depends on locale)
		const createdAtElement = screen.getByText('Created At').nextElementSibling;
		const updatedAtElement = screen.getByText('Updated At').nextElementSibling;

		expect(createdAtElement?.textContent).not.toBe('2024-01-01T00:00:00Z');
		expect(updatedAtElement?.textContent).not.toBe('2024-01-02T00:00:00Z');
	});

	it('handles single user correctly', () => {
		const singleUserProject: Project = {
			...mockProject,
			users: ['single-user-uuid']
		};

		render(ProjectInfo, { props: { project: singleUserProject } });

		expect(screen.getByText('1 user')).toBeInTheDocument(); // Singular form
	});
});

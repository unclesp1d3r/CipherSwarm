import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import { vi, describe, it, expect, beforeEach } from 'vitest';
import AgentList from './AgentList.svelte';

// Mock fetch to always fail (to trigger mock data)
beforeEach(() => {
	vi.stubGlobal(
		'fetch',
		vi.fn(() => Promise.resolve({ ok: false }))
	);
});

describe('AgentList', () => {
	it('renders table headers', async () => {
		render(AgentList);
		// Wait for loading to finish
		await waitFor(() => expect(screen.queryByText(/Loading agents/i)).not.toBeInTheDocument());
		// Use a function matcher for header text in case of markup splitting
		expect(
			await screen.findByText((content, node) => {
				return node?.tagName === 'TH' && /Agent Name\s*\+\s*OS/.test(content);
			})
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Status/.test(content)
			)
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Temperature/.test(content)
			)
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Utilization/.test(content)
			)
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Current Attempts\/sec/.test(content)
			)
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Average Attempts\/sec/.test(content)
			)
		).toBeInTheDocument();
		expect(
			await screen.findByText(
				(content, node) => node?.tagName === 'TH' && /Current Job/.test(content)
			)
		).toBeInTheDocument();
	});

	it('shows loading state initially', () => {
		render(AgentList);
		expect(screen.getByText(/Loading agents/i)).toBeInTheDocument();
	});

	it('shows search input', () => {
		render(AgentList);
		expect(screen.getByPlaceholderText('Search agents...')).toBeInTheDocument();
	});

	it('shows pagination', async () => {
		render(AgentList);
		await waitFor(() => {
			expect(screen.getByRole('navigation', { name: /pagination/i })).toBeInTheDocument();
		});
	});
});

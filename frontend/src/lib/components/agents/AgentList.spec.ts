import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import AgentList from './AgentList.svelte';
import type { AgentListData } from './AgentList.svelte';

// Mock data matching the AgentListData interface
const mockAgentsData: AgentListData = {
	items: [
		{
			id: 1,
			host_name: 'test-agent-1',
			client_signature: 'test-sig-1',
			custom_label: 'Test Agent 1',
			state: 'active',
			enabled: true,
			advanced_configuration: {
				agent_update_interval: 30,
				use_native_hashcat: false,
				enable_additional_hash_types: false
			},
			devices: ['GPU0', 'CPU'],
			agent_type: 'physical',
			operating_system: 'linux',
			created_at: '2024-01-01T00:00:00Z',
			updated_at: '2024-01-01T00:00:00Z',
			last_seen_at: '2024-01-01T00:00:00Z',
			last_ipaddress: '192.168.1.100',
			projects: []
		},
		{
			id: 2,
			host_name: 'test-agent-2',
			client_signature: 'test-sig-2',
			custom_label: 'Test Agent 2',
			state: 'offline',
			enabled: true,
			advanced_configuration: {
				agent_update_interval: 60,
				use_native_hashcat: true,
				enable_additional_hash_types: true
			},
			devices: ['GPU0', 'GPU1'],
			agent_type: 'virtual',
			operating_system: 'windows',
			created_at: '2024-01-01T00:00:00Z',
			updated_at: '2024-01-01T00:00:00Z',
			last_seen_at: '2024-01-01T00:00:00Z',
			last_ipaddress: '192.168.1.101',
			projects: []
		}
	],
	page: 1,
	page_size: 20,
	total: 2,
	search: null,
	state: null
};

describe('AgentList', () => {
	it('renders table headers', () => {
		render(AgentList, { agents: mockAgentsData });

		// Check for the actual table headers in the new structure
		expect(screen.getByText('Agent Name + OS')).toBeInTheDocument();
		expect(screen.getByText('Status')).toBeInTheDocument();
		expect(screen.getByText('Label')).toBeInTheDocument();
		expect(screen.getByText('Devices')).toBeInTheDocument();
		expect(screen.getByText('Last Seen')).toBeInTheDocument();
		expect(screen.getByText('IP Address')).toBeInTheDocument();
	});

	it('renders agent data', () => {
		render(AgentList, { agents: mockAgentsData });

		// Check that agent data is displayed
		expect(screen.getByText('test-agent-1')).toBeInTheDocument();
		expect(screen.getByText('test-agent-2')).toBeInTheDocument();
		expect(screen.getByText('Test Agent 1')).toBeInTheDocument();
		expect(screen.getByText('Test Agent 2')).toBeInTheDocument();
		expect(screen.getByText('linux')).toBeInTheDocument();
		expect(screen.getByText('windows')).toBeInTheDocument();
	});

	it('shows search input', () => {
		render(AgentList, { agents: mockAgentsData });
		expect(screen.getByPlaceholderText('Search agents...')).toBeInTheDocument();
	});

	it('displays agent status badges', () => {
		render(AgentList, { agents: mockAgentsData });

		// Check for status badges
		expect(screen.getByText('Online')).toBeInTheDocument(); // active state
		expect(screen.getByText('Offline')).toBeInTheDocument(); // offline state
	});
});

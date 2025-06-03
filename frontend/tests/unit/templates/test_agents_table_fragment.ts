import { render } from '@testing-library/svelte';
import AgentTable from '../../../src/lib/components/agents/AgentTable.svelte';
import AgentBenchmarks from '../../../src/lib/components/agents/AgentBenchmarks.svelte';
import AgentHardware from '../../../src/lib/components/agents/AgentHardware.svelte';
import AgentPerformance from '../../../src/lib/components/agents/AgentPerformance.svelte';
import AgentErrorLog from '../../../src/lib/components/agents/AgentErrorLog.svelte';
import { describe, it, expect } from 'vitest';

describe('AgentTable', () => {
    it('renders empty state', () => {
        const { getByText } = render(AgentTable, { agents: [] });
        expect(getByText('No agents found.')).toBeTruthy();
    });
    it('renders agent row', () => {
        const agent = { id: 1, host_name: 'host1', operating_system: 'Linux', state: 'active', devices: ['GPU0'], last_seen_at: '2024-06-01T12:00:00Z' };
        const { getByText } = render(AgentTable, { agents: [agent] });
        expect(getByText('host1')).toBeTruthy();
        expect(getByText('Linux')).toBeTruthy();
        expect(getByText('active')).toBeTruthy();
        expect(getByText('GPU0')).toBeTruthy();
    });
});

describe('AgentBenchmarks', () => {
    it('renders empty state', () => {
        const { getByText } = render(AgentBenchmarks, { benchmarks_by_hash_type: {} });
        expect(getByText('No benchmark results available for this agent.')).toBeTruthy();
    });
});

describe('AgentHardware', () => {
    it('renders device list', () => {
        const agent = { id: 1, devices: ['GPU0', 'GPU1'], operating_system: 'Linux' };
        const advanced_configuration = {};
        const { getByText } = render(AgentHardware, { agent, advanced_configuration });
        expect(getByText('GPU0')).toBeTruthy();
        expect(getByText('GPU1')).toBeTruthy();
    });
});

describe('AgentPerformance', () => {
    it('renders empty state', () => {
        const { getByText } = render(AgentPerformance, { series: [] });
        expect(getByText('No device performance data available for this agent.')).toBeTruthy();
    });
});

describe('AgentErrorLog', () => {
    it('renders empty state', () => {
        const { getByText } = render(AgentErrorLog, { errors: [] });
        expect(getByText('No errors reported for this agent.')).toBeTruthy();
    });
}); 
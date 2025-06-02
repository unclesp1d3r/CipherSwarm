import { render } from '@testing-library/svelte';
import Layout from '../../../src/routes/+layout.svelte';
import { describe, it, expect } from 'vitest';

// Minimal smoke test for layout

describe('Root Layout', () => {
    it('renders sidebar, header, toaster, and slot', () => {
        const { getByText, container } = render(Layout, {
            slots: { default: '<div>Test Content</div>' }
        });
        // Sidebar
        expect(getByText('CipherSwarm')).toBeTruthy();
        expect(getByText('Dashboard')).toBeTruthy();
        // Header
        expect(getByText('Project')).toBeTruthy();
        // Toaster (should be in DOM)
        expect(container.querySelector('.toaster')).toBeTruthy();
        // Slot content
        expect(getByText('Test Content')).toBeTruthy();
    });
    // TODO: Add tests for session/project/user state when implemented
});

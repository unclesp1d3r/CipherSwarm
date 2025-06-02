import { render } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import TestWrapper from './TestWrapper.svelte';

// Minimal smoke test for layout

describe('Root Layout', () => {
    it('renders sidebar, header, toaster, and slot', () => {
        const { getByText, container } = render(TestWrapper);
        // Sidebar
        expect(getByText('CipherSwarm')).toBeTruthy();
        expect(getByText('Dashboard')).toBeTruthy();
        // Header
        expect(getByText('Project')).toBeTruthy();
        // Toaster (should be in DOM)
        expect(container.querySelector('[aria-label="Notifications alt+T"]')).toBeTruthy();
        // Slot content
        expect(getByText('Test Content')).toBeTruthy();
    });
    // TODO: Add tests for session/project/user state when implemented
});

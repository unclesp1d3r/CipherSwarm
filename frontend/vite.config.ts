import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { svelteTesting } from '@testing-library/svelte/vite';

export default defineConfig(({ mode }) => {
    const isDev = mode === 'development';
    const isTest = mode === 'test' || process.env.VITEST;

    // Backend API URL - use environment variable if available, fallback to localhost
    const defaultApiUrl = process.env.API_BASE_URL || 'http://localhost:8000';

    return {
        plugins: [tailwindcss(), sveltekit(), svelteTesting({ resolveBrowser: true })],
        resolve: isTest ? { conditions: ['browser'] } : undefined,

        // Development server configuration
        server: {
            port: 5173,
            strictPort: true,
            open: false,
            proxy: isDev
                ? {
                    // Specific proxy for SSE endpoints to handle EventSource properly
                    '/api/v1/web/live': {
                        target: defaultApiUrl,
                        changeOrigin: true,
                        secure: false,
                        ws: false, // Disable websocket upgrade for SSE
                        configure: (proxy, _options) => {
                            proxy.on('error', (err, _req, _res) => {
                                console.log('SSE proxy error', err);
                            });
                            proxy.on('proxyReq', (proxyReq, req, _res) => {
                                console.log(
                                    'Sending SSE Request to the Target:',
                                    req.method,
                                    req.url
                                );
                                // Ensure proper headers for SSE
                                proxyReq.setHeader('Accept', 'text/event-stream');
                                proxyReq.setHeader('Cache-Control', 'no-cache');
                            });
                            proxy.on('proxyRes', (proxyRes, req, _res) => {
                                console.log(
                                    'Received SSE Response from the Target:',
                                    proxyRes.statusCode,
                                    req.url
                                );
                            });
                        },
                    },
                    // General API proxy for all other endpoints
                    '/api': {
                        target: defaultApiUrl,
                        changeOrigin: true,
                        secure: false,
                        configure: (proxy, _options) => {
                            proxy.on('error', (err, _req, _res) => {
                                console.log('proxy error', err);
                            });
                            proxy.on('proxyReq', (proxyReq, req, _res) => {
                                console.log(
                                    'Sending Request to the Target:',
                                    req.method,
                                    req.url
                                );
                            });
                            proxy.on('proxyRes', (proxyRes, req, _res) => {
                                console.log(
                                    'Received Response from the Target:',
                                    proxyRes.statusCode,
                                    req.url
                                );
                            });
                        },
                    },
                }
                : undefined,
        },

        // Build configuration
        build: {
            outDir: 'build',
            emptyOutDir: true,
            // SSR-specific build optimizations
            rollupOptions: {
                output: {
                    // Ensure consistent chunk naming for SSR
                    chunkFileNames: 'chunks/[name]-[hash].js',
                    entryFileNames: 'entries/[name]-[hash].js',
                    assetFileNames: 'assets/[name]-[hash].[ext]',
                },
            },
        },

        // Environment variables configuration
        envPrefix: ['VITE_', 'PUBLIC_'],
        define: {
            // Make API base URL available to the application
            __API_BASE_URL__: JSON.stringify(process.env.VITE_API_BASE_URL || defaultApiUrl),
        },

        // Test configuration
        test: {
            name: 'client',
            environment: 'jsdom',
            clearMocks: true,
            include: ['src/**/*.svelte.{test,spec}.{js,ts}', 'src/**/*.spec.ts'],
            exclude: ['src/lib/server/**'],
            setupFiles: ['./vitest-setup-client.ts'],
            // Environment variables for testing
            env: {
                VITE_API_BASE_URL: 'http://localhost:8000',
            },
        },

        // SSR-specific optimizations
        ssr: {
            // Don't externalize these packages for SSR
            noExternal: ['@internationalized/date', 'bits-ui', 'formsnap', 'mode-watcher'],
        },
    };
});

import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { svelteTesting } from '@testing-library/svelte/vite';

export default defineConfig(({ mode }) => {
    const isDev = mode === 'development';
    const isTest = mode === 'test' || process.env.VITEST;

    // Default backend API URL - can be overridden by environment variables
    const defaultApiUrl = isDev
        ? 'http://localhost:8000'
        : process.env.API_BASE_URL || 'http://localhost:8000';

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
                    // Proxy API requests to backend in development
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
                        }
                    }
                }
                : undefined
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
                    assetFileNames: 'assets/[name]-[hash].[ext]'
                }
            }
        },

        // Environment variables configuration
        envPrefix: ['VITE_', 'PUBLIC_'],
        define: {
            // Make API base URL available to the application
            __API_BASE_URL__: JSON.stringify(process.env.VITE_API_BASE_URL || defaultApiUrl)
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
                VITE_API_BASE_URL: 'http://localhost:8000'
            }
        },

        // SSR-specific optimizations
        ssr: {
            // Don't externalize these packages for SSR
            noExternal: ['@internationalized/date', 'bits-ui', 'formsnap', 'mode-watcher']
        }
    };
});

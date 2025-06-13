import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

const config = {
	preprocess: vitePreprocess(),
	kit: {
		adapter: adapter(),
		alias: { '@/*': './src/lib/*' },
		prerender: {
			handleHttpError: 'warn',
			entries: [] // Disable prerendering since this is an authenticated SSR app
		}
	}
};

export default config;

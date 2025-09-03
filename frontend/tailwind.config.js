import { catppuccin } from '@catppuccin/tailwindcss';

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        accent: '#9400D3', // DarkViolet
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [
    catppuccin({
      prefix: false,
      defaultFlavour: 'macchiato'
    }),
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography')
  ],
};
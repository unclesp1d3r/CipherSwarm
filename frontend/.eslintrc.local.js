module.exports = {
    rules: {
        // Disable the no-unassigned-vars rule for Svelte component props
        'eslint/no-unassigned-vars': 'off',

        // Keep other linting rules active
        '@typescript-eslint/no-explicit-any': 'error',
        'eslint-plugin-unicorn/prefer-string-replace-all': 'error',
    },
};

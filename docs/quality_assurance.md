# Source code quality assurance and best praxis

## EditorConfig

[EditorConfig](https://editorconfig.org) helps maintain consistent coding styles for multiple developers working on the same project across various editors and IDEs.

Also check out Microsoft Visual Studio Code Extension:

[EditorConfig for VS Code](https://marketplace.visualstudio.com/items?itemName=EditorConfig.EditorConfig)

In VS Code you can add vertical rulers in `settings.json` by adding:

```json
"editor.rulers": [
  {"column": 120, "color": "#5a5a5a"}, // Code
  {"column": 80, "color": "#5a5a5a"} // CHANGELOG
]
```

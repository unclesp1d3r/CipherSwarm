# CipherSwarm Component Styling Standards

## Catppuccin Theme Integration

### Color System

CipherSwarm uses the **Catppuccin Macchiato** palette with **DarkViolet (#9400D3)** as the accent color.

#### Color Variables (CSS Custom Properties)

```css
/* Light Mode */
:root {
  --background: #eff1f5;    /* Base */
  --foreground: #24273a;    /* Text */
  --primary: #9400D3;       /* DarkViolet accent */
  --destructive: #ed8796;   /* Red */
  --border: #e4e4e7;        /* Surface0 */
  /* ... additional Catppuccin colors */
}

/* Dark Mode */
.dark {
  --background: #24273a;    /* Base */
  --foreground: #cad3f5;    /* Text */
  --primary: #9400D3;       /* DarkViolet accent */
  --destructive: #ed8796;   /* Red */
  --border: #494d64;        /* Surface1 */
  /* ... additional Catppuccin colors */
}
```

### Typography

- **Font Stack**: `Inter, system-ui, sans-serif`
- **Text Sizes**: `text-xs` (12px) to `text-4xl` (36px)
- **Semantic Colors**: 
  - Primary text: `text-foreground`
  - Secondary text: `text-muted-foreground`
  - Success: `text-green-500 dark:text-green-400`
  - Error: `text-red-500 dark:text-red-400`
  - Warning: `text-yellow-500 dark:text-yellow-400`
  - Info: `text-blue-500 dark:text-blue-400`

## Component Standards

### Buttons

Using existing `buttonVariants` from Shadcn-Svelte with Catppuccin colors:

```typescript
// Primary button (DarkViolet accent)
<Button variant="default">Primary Action</Button>

// Secondary button
<Button variant="secondary">Secondary Action</Button>

// Destructive button (Catppuccin red)
<Button variant="destructive">Delete</Button>

// Ghost button
<Button variant="ghost">Cancel</Button>
```

### Form Elements

#### Input Fields
```svelte
<!-- Normal state -->
<Input placeholder="Enter text..." />

<!-- Error state (uses aria-invalid for styling) -->
<Input aria-invalid="true" placeholder="Invalid input" />
```

Error styling is automatically applied via `aria-invalid:border-destructive` classes.

#### Form Validation
- Error borders: Automatically applied via `aria-invalid` attribute
- Error text: Use `text-destructive` class
- Error icons: Use `text-destructive` with error icons

### Tooltips

```svelte
<!-- Catppuccin surface colors -->
<div class="bg-popover text-popover-foreground rounded-md px-2 py-1 text-sm shadow-md">
  Tooltip content
</div>
```

### Toast Notifications

```typescript
import { toast } from '$lib/stores/toast';

// Success toast (green)
toast.success('Operation completed', 'The task was completed successfully');

// Error toast (red, persistent by default)
toast.error('Operation failed', 'Please try again');

// Warning toast (yellow)
toast.warning('Warning', 'This action cannot be undone');

// Info toast (blue)
toast.info('Information', 'New feature available');
```

### Icons

```svelte
<script>
  import Icon from '$lib/components/ui/icon.svelte';
</script>

<!-- Attack type icons -->
<Icon name="dictionary" size="md" />
<Icon name="mask" size="lg" />
<Icon name="brute_force" size="sm" />

<!-- General icons -->
<Icon name="settings" class="text-muted-foreground" />
<Icon name="success" class="text-green-500" />
```

#### Attack Type Icon Mappings

| Attack Type | Icon | Lucide Icon Name |
|-------------|------|------------------|
| Dictionary | 📖 | `book-open` |
| Mask | ⌨️ | `command` |
| Brute Force | # | `hash` |
| Hybrid | 🔀 | `merge` |
| Previous Passwords | ↺ | `rotate-ccw` |
| Rule-based | 🎚️ | `sliders-horizontal` |

### Tables

```svelte
<!-- Flowbite-style table with alternating rows -->
<table class="w-full text-sm text-left">
  <thead class="text-xs uppercase bg-muted">
    <tr>
      <th class="px-6 py-3">Column</th>
    </tr>
  </thead>
  <tbody>
    <tr class="border-b hover:bg-muted/50">
      <td class="px-6 py-4">Data</td>
    </tr>
  </tbody>
</table>
```

### Modals

```svelte
<!-- Flowbite layout with max-w-2xl -->
<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
  <div class="relative max-w-2xl w-full mx-4 bg-background rounded-lg shadow-lg">
    <div class="p-6">
      <!-- Modal content -->
    </div>
  </div>
</div>
```

## Responsive Design

### Minimum Width Support
- **Minimum supported width**: 768px
- **Sidebar**: Collapsible on smaller screens
- **Breakpoints**: Follow Tailwind defaults (sm: 640px, md: 768px, lg: 1024px, xl: 1280px)

### Layout Patterns
```svelte
<!-- Responsive grid -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  <!-- Content -->
</div>

<!-- Responsive text -->
<h1 class="text-xl md:text-2xl lg:text-3xl">Title</h1>
```

## Best Practices

### Color Usage
1. **Always use CSS custom properties** instead of hardcoded colors
2. **Provide dark mode variants** for all custom colors
3. **Use semantic color names** (primary, destructive, muted, etc.)
4. **Test in both light and dark modes**

### Accessibility
1. **Use proper ARIA attributes** for form validation (`aria-invalid`)
2. **Ensure sufficient color contrast** (Catppuccin colors are designed for this)
3. **Include focus states** (already handled by Shadcn-Svelte components)
4. **Use semantic HTML elements**

### Performance
1. **Use existing Shadcn-Svelte components** when possible
2. **Leverage CSS custom properties** for theming
3. **Minimize custom CSS** by using Tailwind utilities
4. **Use the Icon component** for consistent icon rendering

## Implementation Checklist

- [x] Catppuccin Macchiato palette configured
- [x] DarkViolet accent color integrated
- [x] Icon system with attack type mappings
- [x] Toast notification system
- [x] Form error states use destructive colors
- [x] Button variants use accent colors
- [x] Dark mode support
- [ ] Tooltip styling verification
- [ ] Modal styling verification
- [ ] Table styling verification
- [ ] Responsive design testing
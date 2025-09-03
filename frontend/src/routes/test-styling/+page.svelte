<script lang="ts">
  import { onMount } from 'svelte';
  import Button from '$lib/components/ui/button/button.svelte';
  import Icon from '$lib/components/ui/icon.svelte';
  import Input from '$lib/components/ui/input/input.svelte';
  import Card from '$lib/components/ui/card/card.svelte';
  import CardHeader from '$lib/components/ui/card/card-header.svelte';
  import CardTitle from '$lib/components/ui/card/card-title.svelte';
  import CardContent from '$lib/components/ui/card/card-content.svelte';
  import ToastContainer from '$lib/components/ui/toast-container.svelte';
  import { toast } from '$lib/stores/toast.js';

  let testInput = $state('');
  let hasError = $state(false);

  function showSuccessToast() {
    toast.success('Success!', 'The Catppuccin theme is working correctly.');
  }

  function showErrorToast() {
    toast.error('Error Test', 'This is a test error message.');
  }

  function showWarningToast() {
    toast.warning('Warning', 'This is a test warning message.');
  }

  function showInfoToast() {
    toast.info('Info', 'This is a test info message.');
  }

  function toggleError() {
    hasError = !hasError;
  }
</script>

<svelte:head>
  <title>Style System Test - CipherSwarm</title>
</svelte:head>

<div class="container mx-auto py-8 space-y-8">
  <div class="text-center">
    <h1 class="text-4xl font-bold mb-4">CipherSwarm Style System Test</h1>
    <p class="text-muted-foreground">Testing Catppuccin theme, icons, and components</p>
  </div>

  <!-- Color Palette Test -->
  <Card>
    <CardHeader>
      <CardTitle>Color Palette Test</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 text-center text-sm">
        <div class="p-4 rounded bg-primary text-primary-foreground">Primary</div>
        <div class="p-4 rounded bg-secondary text-secondary-foreground">Secondary</div>
        <div class="p-4 rounded bg-destructive text-white">Destructive</div>
        <div class="p-4 rounded bg-muted text-muted-foreground">Muted</div>
        <div class="p-4 rounded bg-accent text-accent-foreground">Accent</div>
        <div class="p-4 rounded bg-card text-card-foreground border">Card</div>
        <div class="p-4 rounded bg-popover text-popover-foreground border">Popover</div>
        <div class="p-4 rounded bg-background text-foreground border">Background</div>
      </div>
    </CardContent>
  </Card>

  <!-- Button Variants Test -->
  <Card>
    <CardHeader>
      <CardTitle>Button Variants</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="flex flex-wrap gap-4">
        <Button variant="default">Default</Button>
        <Button variant="secondary">Secondary</Button>
        <Button variant="destructive">Destructive</Button>
        <Button variant="outline">Outline</Button>
        <Button variant="ghost">Ghost</Button>
        <Button variant="link">Link</Button>
      </div>
    </CardContent>
  </Card>

  <!-- Icons Test -->
  <Card>
    <CardHeader>
      <CardTitle>Attack Type Icons</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="flex items-center gap-2">
          <Icon name="dictionary" class="text-primary" />
          <span>Dictionary</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="mask" class="text-primary" />
          <span>Mask</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="brute_force" class="text-primary" />
          <span>Brute Force</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="hybrid" class="text-primary" />
          <span>Hybrid</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="previous_passwords" class="text-primary" />
          <span>Previous Passwords</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="rule_based" class="text-primary" />
          <span>Rule-based</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="combinator" class="text-primary" />
          <span>Combinator</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="wordlist" class="text-primary" />
          <span>Wordlist</span>
        </div>
      </div>
    </CardContent>
  </Card>

  <!-- Form Elements Test -->
  <Card>
    <CardHeader>
      <CardTitle>Form Elements</CardTitle>
    </CardHeader>
    <CardContent class="space-y-4">
      <div>
        <label for="test-input" class="block text-sm font-medium mb-2">Test Input</label>
        <Input 
          id="test-input"
          bind:value={testInput} 
          placeholder="Enter some text..." 
          aria-invalid={hasError}
        />
        {#if hasError}
          <p class="text-destructive text-sm mt-1">
            <Icon name="error" size="sm" class="inline mr-1" />
            This field has an error
          </p>
        {/if}
      </div>
      <Button onclick={toggleError} variant="outline">
        {hasError ? 'Remove Error' : 'Show Error State'}
      </Button>
    </CardContent>
  </Card>

  <!-- Toast Notifications Test -->
  <Card>
    <CardHeader>
      <CardTitle>Toast Notifications</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="flex flex-wrap gap-4">
        <Button onclick={showSuccessToast} variant="default">
          <Icon name="success" size="sm" />
          Success Toast
        </Button>
        <Button onclick={showErrorToast} variant="destructive">
          <Icon name="error" size="sm" />
          Error Toast
        </Button>
        <Button onclick={showWarningToast} variant="outline">
          <Icon name="warning" size="sm" />
          Warning Toast
        </Button>
        <Button onclick={showInfoToast} variant="secondary">
          <Icon name="info" size="sm" />
          Info Toast
        </Button>
      </div>
    </CardContent>
  </Card>

  <!-- Semantic Colors Test -->
  <Card>
    <CardHeader>
      <CardTitle>Semantic Colors</CardTitle>
    </CardHeader>
    <CardContent>
      <div class="space-y-4">
        <div class="flex items-center gap-2">
          <Icon name="success" class="text-green-500 dark:text-green-400" />
          <span class="text-green-500 dark:text-green-400">Success message</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="error" class="text-red-500 dark:text-red-400" />
          <span class="text-red-500 dark:text-red-400">Error message</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="warning" class="text-yellow-500 dark:text-yellow-400" />
          <span class="text-yellow-500 dark:text-yellow-400">Warning message</span>
        </div>
        <div class="flex items-center gap-2">
          <Icon name="info" class="text-blue-500 dark:text-blue-400" />
          <span class="text-blue-500 dark:text-blue-400">Info message</span>
        </div>
      </div>
    </CardContent>
  </Card>
</div>

<!-- Toast Container -->
<ToastContainer />
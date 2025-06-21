<script lang="ts">
    import { type SuperForm } from 'sveltekit-superforms';
    import { type AttackFormData } from '$lib/schemas/attack.js';
    import {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    } from '$lib/components/ui/card/index.js';
    import { Label } from '$lib/components/ui/label/index.js';
    import {
        Select,
        SelectContent,
        SelectItem,
        SelectTrigger,
    } from '$lib/components/ui/select/index.js';
    import { Badge } from '$lib/components/ui/badge/index.js';
    import { Button } from '$lib/components/ui/button/index.js';
    import { Trash2, Plus } from 'lucide-svelte';

    interface Props {
        form: SuperForm<AttackFormData>;
        wordlists: Array<{ id: string; name: string; line_count?: number }>;
        rulelists: Array<{ id: string; name: string; rule_count?: number }>;
    }

    let { form, wordlists, rulelists }: Props = $props();

    const { form: formData, enhance } = form;

    // Helper to get selected wordlist details
    function getWordlistDetails(id: string) {
        return wordlists.find((w) => w.id === id);
    }

    // Helper to get selected rulelist details
    function getRulelistDetails(id: string) {
        return rulelists.find((r) => r.id === id);
    }

    // Add wordlist to selection
    function addWordlist() {
        if ($formData.attack_mode === 'dictionary') {
            if ($formData.wordlists && $formData.wordlists.length > 0) {
                $formData.wordlists = [...$formData.wordlists, ''];
            } else {
                $formData.wordlists = [''];
            }
        }
    }

    // Remove wordlist from selection
    function removeWordlist(index: number) {
        if ($formData.attack_mode === 'dictionary' && $formData.wordlists) {
            $formData.wordlists = $formData.wordlists.filter((_, i) => i !== index);
        }
    }

    // Add rulelist to selection
    function addRulelist() {
        if ($formData.attack_mode === 'dictionary') {
            if ($formData.rulelists && $formData.rulelists.length > 0) {
                $formData.rulelists = [...$formData.rulelists, ''];
            } else {
                $formData.rulelists = [''];
            }
        }
    }

    // Remove rulelist from selection
    function removeRulelist(index: number) {
        if ($formData.attack_mode === 'dictionary' && $formData.rulelists) {
            $formData.rulelists = $formData.rulelists.filter((_, i) => i !== index);
        }
    }

    // Show resources section based on attack mode
    const showWordlists = $derived($formData.attack_mode === 'dictionary');
    const showRulelists = $derived($formData.attack_mode === 'dictionary');
</script>

<div class="space-y-6">
    <div class="text-center">
        <h3 class="text-lg font-semibold">Select Resources</h3>
        <p class="text-muted-foreground text-sm">
            Choose the wordlists and rule files for your attack
        </p>
    </div>

    {#if showWordlists}
        <Card>
            <CardHeader>
                <CardTitle class="flex items-center justify-between">
                    Wordlists
                    <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onclick={addWordlist}
                        data-testid="add-wordlist-button">
                        <Plus class="mr-2 h-4 w-4" />
                        Add Wordlist
                    </Button>
                </CardTitle>
                <CardDescription>
                    Select one or more wordlists to use in the dictionary attack
                </CardDescription>
            </CardHeader>
            <CardContent class="space-y-4">
                {#if $formData.attack_mode === 'dictionary' && $formData.wordlists && $formData.wordlists.length > 0}
                    {#each $formData.wordlists as wordlistId, index (index)}
                        <div class="flex items-center gap-4">
                            <div class="flex-1">
                                <Label for="wordlist-{index}">Wordlist {index + 1}</Label>
                                <Select type="single" bind:value={$formData.wordlists[index]}>
                                    <SelectTrigger data-testid="wordlist-select-{index}">
                                        {wordlistId
                                            ? getWordlistDetails(wordlistId)?.name ||
                                              'Select a wordlist...'
                                            : 'Select a wordlist...'}
                                    </SelectTrigger>
                                    <SelectContent>
                                        {#each wordlists as wordlist (wordlist.id)}
                                            <SelectItem value={wordlist.id}>
                                                <div
                                                    class="flex w-full items-center justify-between">
                                                    <span>{wordlist.name}</span>
                                                    {#if wordlist.line_count}
                                                        <Badge variant="secondary" class="ml-2">
                                                            {wordlist.line_count.toLocaleString()} lines
                                                        </Badge>
                                                    {/if}
                                                </div>
                                            </SelectItem>
                                        {/each}
                                    </SelectContent>
                                </Select>
                            </div>
                            {#if $formData.wordlists.length > 1}
                                <Button
                                    type="button"
                                    variant="outline"
                                    size="sm"
                                    onclick={() => removeWordlist(index)}
                                    data-testid="remove-wordlist-{index}">
                                    <Trash2 class="h-4 w-4" />
                                </Button>
                            {/if}
                        </div>
                        {#if wordlistId}
                            {@const details = getWordlistDetails(wordlistId)}
                            {#if details}
                                <div class="text-muted-foreground ml-4 text-sm">
                                    Selected: {details.name}
                                    {#if details.line_count}
                                        ({details.line_count.toLocaleString()} lines)
                                    {/if}
                                </div>
                            {/if}
                        {/if}
                    {/each}
                {:else}
                    <div class="text-muted-foreground py-8 text-center">
                        <p>No wordlists selected</p>
                        <p class="text-sm">Click "Add Wordlist" to get started</p>
                    </div>
                {/if}
            </CardContent>
        </Card>
    {/if}

    {#if showRulelists}
        <Card>
            <CardHeader>
                <CardTitle class="flex items-center justify-between">
                    Rule Lists (Optional)
                    <Button
                        type="button"
                        variant="outline"
                        size="sm"
                        onclick={addRulelist}
                        data-testid="add-rulelist-button">
                        <Plus class="mr-2 h-4 w-4" />
                        Add Rule List
                    </Button>
                </CardTitle>
                <CardDescription>
                    Optionally select rule lists to modify the wordlist entries
                </CardDescription>
            </CardHeader>
            <CardContent class="space-y-4">
                {#if $formData.attack_mode === 'dictionary' && $formData.rulelists && $formData.rulelists.length > 0}
                    {#each $formData.rulelists as rulelistId, index (index)}
                        <div class="flex items-center gap-4">
                            <div class="flex-1">
                                <Label for="rulelist-{index}">Rule List {index + 1}</Label>
                                <Select type="single" bind:value={$formData.rulelists[index]}>
                                    <SelectTrigger data-testid="rulelist-select-{index}">
                                        {rulelistId
                                            ? getRulelistDetails(rulelistId)?.name ||
                                              'Select a rule list...'
                                            : 'Select a rule list...'}
                                    </SelectTrigger>
                                    <SelectContent>
                                        {#each rulelists as rulelist (rulelist.id)}
                                            <SelectItem value={rulelist.id}>
                                                <div
                                                    class="flex w-full items-center justify-between">
                                                    <span>{rulelist.name}</span>
                                                    {#if rulelist.rule_count}
                                                        <Badge variant="secondary" class="ml-2">
                                                            {rulelist.rule_count.toLocaleString()} rules
                                                        </Badge>
                                                    {/if}
                                                </div>
                                            </SelectItem>
                                        {/each}
                                    </SelectContent>
                                </Select>
                            </div>
                            <Button
                                type="button"
                                variant="outline"
                                size="sm"
                                onclick={() => removeRulelist(index)}
                                data-testid="remove-rulelist-{index}">
                                <Trash2 class="h-4 w-4" />
                            </Button>
                        </div>
                        {#if rulelistId}
                            {@const details = getRulelistDetails(rulelistId)}
                            {#if details}
                                <div class="text-muted-foreground ml-4 text-sm">
                                    Selected: {details.name}
                                    {#if details.rule_count}
                                        ({details.rule_count.toLocaleString()} rules)
                                    {/if}
                                </div>
                            {/if}
                        {/if}
                    {/each}
                {:else}
                    <div class="text-muted-foreground py-8 text-center">
                        <p>No rule lists selected</p>
                        <p class="text-sm">Rule lists are optional for dictionary attacks</p>
                    </div>
                {/if}
            </CardContent>
        </Card>
    {/if}

    {#if !showWordlists && !showRulelists}
        <Card>
            <CardContent class="py-12">
                <div class="text-muted-foreground text-center">
                    <p class="text-lg font-medium">No Resources Required</p>
                    <p class="text-sm">
                        The selected attack mode ({$formData.attack_mode}) doesn't require
                        additional resources.
                    </p>
                </div>
            </CardContent>
        </Card>
    {/if}
</div>

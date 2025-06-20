<script lang="ts">
    import { Button } from '$lib/components/ui/button';
    import { Input } from '$lib/components/ui/input';
    import { Label } from '$lib/components/ui/label';
    import { Popover, PopoverContent, PopoverTrigger } from '$lib/components/ui/popover';
    import {
        Command,
        CommandEmpty,
        CommandGroup,
        CommandInput,
        CommandItem,
        CommandList
    } from '$lib/components/ui/command';
    import { Badge } from '$lib/components/ui/badge';
    import { Check, ChevronDown, HelpCircle } from '@lucide/svelte';
    import { cn } from '$lib/utils';
    import { createEventDispatcher } from 'svelte';

    interface RuleList {
        id: string;
        file_name: string;
        line_count?: number;
    }

    export let rulelists: RuleList[] = [];
    export let selectedRuleId: string | null = null;
    export let placeholder = '-- No Rule List --';
    export let label = 'Rule List';
    export let disabled = false;
    export let required = false;

    const dispatch = createEventDispatcher<{
        select: { ruleId: string | null };
        showExplanation: void;
    }>();

    let open = false;
    let searchValue = '';

    $: selectedRule = rulelists.find((rule) => rule.id === selectedRuleId);
    $: filteredRules = rulelists.filter((rule) =>
        rule.file_name.toLowerCase().includes(searchValue.toLowerCase())
    );

    function handleSelect(ruleId: string | null) {
        selectedRuleId = ruleId;
        open = false;
        dispatch('select', { ruleId });
    }

    function handleShowExplanation() {
        dispatch('showExplanation');
    }
</script>

<div class="space-y-2">
    <div class="flex items-center gap-2">
        <Label for="rule-list-select" class="text-sm font-medium">
            {label}
            {#if required}
                <span class="text-destructive">*</span>
            {/if}
        </Label>
        <Button
            variant="ghost"
            size="sm"
            class="h-6 w-6 p-0"
            onclick={handleShowExplanation}
            aria-label="Show rule explanation"
        >
            <HelpCircle class="h-4 w-4" />
        </Button>
    </div>

    <div class="flex items-center gap-2">
        <Popover bind:open>
            <PopoverTrigger>
                <Button
                    variant="outline"
                    role="combobox"
                    aria-expanded={open}
                    class="w-full justify-between"
                    {disabled}
                >
                    {selectedRule ? selectedRule.file_name : placeholder}
                    <ChevronDown class="ml-2 h-4 w-4 shrink-0 opacity-50" />
                </Button>
            </PopoverTrigger>
            <PopoverContent class="w-full p-0">
                <Command>
                    <CommandInput placeholder="Search rules..." bind:value={searchValue} />
                    <CommandList>
                        <CommandEmpty>No rules found.</CommandEmpty>
                        <CommandGroup>
                            <CommandItem value="" onSelect={() => handleSelect(null)}>
                                <Check
                                    class={cn(
                                        'mr-2 h-4 w-4',
                                        selectedRuleId === null ? 'opacity-100' : 'opacity-0'
                                    )}
                                />
                                {placeholder}
                            </CommandItem>
                            {#each filteredRules as rule (rule.id)}
                                <CommandItem value={rule.id} onSelect={() => handleSelect(rule.id)}>
                                    <Check
                                        class={cn(
                                            'mr-2 h-4 w-4',
                                            selectedRuleId === rule.id ? 'opacity-100' : 'opacity-0'
                                        )}
                                    />
                                    <div class="flex w-full items-center justify-between">
                                        <span>{rule.file_name}</span>
                                        {#if rule.line_count}
                                            <Badge variant="secondary" class="ml-2 text-xs">
                                                {rule.line_count.toLocaleString()} rules
                                            </Badge>
                                        {/if}
                                    </div>
                                </CommandItem>
                            {/each}
                        </CommandGroup>
                    </CommandList>
                </Command>
            </PopoverContent>
        </Popover>
    </div>

    {#if rulelists.length === 0}
        <p class="text-muted-foreground text-xs">No rule lists available.</p>
    {/if}
</div>

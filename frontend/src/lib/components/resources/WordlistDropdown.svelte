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
        CommandList,
    } from '$lib/components/ui/command';
    import { Badge } from '$lib/components/ui/badge';
    import { Check, ChevronDown } from '@lucide/svelte';
    import { cn } from '$lib/utils';
    import { createEventDispatcher } from 'svelte';

    interface WordList {
        id: string;
        file_name: string;
        line_count?: number;
    }

    export let wordlists: WordList[] = [];
    export let selectedWordlistId: string | null = null;
    export let placeholder = '-- No Word List --';
    export let label = 'Word List';
    export let disabled = false;
    export let required = false;

    const dispatch = createEventDispatcher<{
        select: { wordlistId: string | null };
        search: { query: string };
    }>();

    let open = false;
    let searchValue = '';

    $: selectedWordlist = wordlists.find((wl) => wl.id === selectedWordlistId);
    $: filteredWordlists = wordlists.filter((wl) =>
        wl.file_name.toLowerCase().includes(searchValue.toLowerCase())
    );

    function handleSelect(wordlistId: string | null) {
        selectedWordlistId = wordlistId;
        open = false;
        dispatch('select', { wordlistId });
    }

    function handleSearch(query: string) {
        searchValue = query;
        dispatch('search', { query });
    }
</script>

<div class="space-y-2">
    <Label for="wordlist-select" class="text-sm font-medium">
        {label}
        {#if required}
            <span class="text-destructive">*</span>
        {/if}
    </Label>

    <Popover bind:open>
        <PopoverTrigger>
            <Button
                variant="outline"
                role="combobox"
                aria-expanded={open}
                class="w-full justify-between"
                {disabled}>
                {selectedWordlist ? selectedWordlist.file_name : placeholder}
                <ChevronDown class="ml-2 h-4 w-4 shrink-0 opacity-50" />
            </Button>
        </PopoverTrigger>
        <PopoverContent class="w-full p-0">
            <Command>
                <CommandInput
                    placeholder="Search wordlists..."
                    bind:value={searchValue}
                    oninput={(e) => handleSearch((e.target as HTMLInputElement)?.value || '')} />
                <CommandList>
                    <CommandEmpty>No wordlists found.</CommandEmpty>
                    <CommandGroup>
                        <CommandItem value="" onSelect={() => handleSelect(null)}>
                            <Check
                                class={cn(
                                    'mr-2 h-4 w-4',
                                    selectedWordlistId === null ? 'opacity-100' : 'opacity-0'
                                )} />
                            {placeholder}
                        </CommandItem>
                        {#each filteredWordlists as wordlist (wordlist.id)}
                            <CommandItem
                                value={wordlist.id}
                                onSelect={() => handleSelect(wordlist.id)}>
                                <Check
                                    class={cn(
                                        'mr-2 h-4 w-4',
                                        selectedWordlistId === wordlist.id
                                            ? 'opacity-100'
                                            : 'opacity-0'
                                    )} />
                                <div class="flex w-full items-center justify-between">
                                    <span>{wordlist.file_name}</span>
                                    {#if wordlist.line_count}
                                        <Badge variant="secondary" class="ml-2 text-xs">
                                            {wordlist.line_count.toLocaleString()} entries
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

    {#if wordlists.length === 0}
        <p class="text-muted-foreground text-xs">No wordlists found.</p>
    {/if}
</div>

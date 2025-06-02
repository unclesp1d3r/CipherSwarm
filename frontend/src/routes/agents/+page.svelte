<script lang="ts">
  import { Card, CardHeader, CardTitle, CardContent } from '$lib/components/ui/card';
  import { Table, TableHead, TableRow, TableHeader, TableBody, TableCell } from '$lib/components/ui/table';
  import { Button } from '$lib/components/ui/button';
  import { Dialog, DialogTrigger, DialogContent, DialogTitle } from '$lib/components/ui/dialog';
  import { Input } from '$lib/components/ui/input';
  
  // TODO: Replace with live data from API
  let agents = [
    { id: 1, name: 'Agent-01', status: 'Online', lastSeen: '1m ago', task: 'Campaign X', guessRate: '55 MH/s' },
    { id: 2, name: 'Agent-02', status: 'Offline', lastSeen: '10m ago', task: 'Idle', guessRate: '0 MH/s' },
    { id: 3, name: 'Agent-03', status: 'Online', lastSeen: '2m ago', task: 'Campaign Y', guessRate: '42 MH/s' },
  ];
  let search = '';
  let showRegisterModal = false;
  
  // TODO: Implement filtering logic
  $: filteredAgents = agents.filter(a => a.name.toLowerCase().includes(search.toLowerCase()));
</script>

<h1 class="sr-only">Agents</h1>
<Card class="mt-8 mx-auto max-w-5xl">
  <CardHeader class="flex flex-row items-center justify-between">
    <CardTitle>Agents</CardTitle>
    <div class="flex gap-2">
      <Input
        placeholder="Search agents..."
        bind:value={search}
        class="w-64"
        aria-label="Search agents"
      />
      <Dialog bind:open={showRegisterModal}>
        <DialogTrigger>
          <Button variant="default">Register Agent</Button>
        </DialogTrigger>
        <DialogContent>
          <DialogTitle>Register New Agent</DialogTitle>
          <!-- TODO: Implement registration form -->
          <div class="py-4 text-muted-foreground">Registration form goes here.</div>
        </DialogContent>
      </Dialog>
    </div>
  </CardHeader>
  <CardContent>
    <Table>
      <TableHead>
        <TableRow>
          <TableHeader>Name</TableHeader>
          <TableHeader>Status</TableHeader>
          <TableHeader>Last Seen</TableHeader>
          <TableHeader>Current Task</TableHeader>
          <TableHeader>Guess Rate</TableHeader>
          <TableHeader>Actions</TableHeader>
        </TableRow>
      </TableHead>
      <TableBody>
        {#each filteredAgents as agent (agent.id)}
          <TableRow>
            <TableCell>{agent.name}</TableCell>
            <TableCell>
              <!-- TODO: Use status badge component -->
              <span class={agent.status === 'Online' ? 'text-green-600' : 'text-gray-400'}>{agent.status}</span>
            </TableCell>
            <TableCell>{agent.lastSeen}</TableCell>
            <TableCell>{agent.task}</TableCell>
            <TableCell>{agent.guessRate}</TableCell>
            <TableCell>
              <!-- TODO: Implement Details and Shutdown modals/dialogs -->
              <Button size="sm" variant="outline" class="mr-2">Details</Button>
              <Button size="sm" variant="destructive">Shutdown</Button>
            </TableCell>
          </TableRow>
        {/each}
      </TableBody>
    </Table>
    {#if filteredAgents.length === 0}
      <div class="text-center text-muted-foreground py-8">No agents found.</div>
    {/if}
  </CardContent>
</Card> 
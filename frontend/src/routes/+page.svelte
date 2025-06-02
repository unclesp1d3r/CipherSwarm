<script lang="ts">
import Card from '$lib/components/ui/card/card.svelte';
import CardHeader from '$lib/components/ui/card/card-header.svelte';
import CardTitle from '$lib/components/ui/card/card-title.svelte';
import CardContent from '$lib/components/ui/card/card-content.svelte';
import Badge from '$lib/components/ui/badge/badge.svelte';
import Accordion from '$lib/components/ui/accordion/accordion-root.svelte';
import AccordionItem from '$lib/components/ui/accordion/accordion-item.svelte';
import AccordionTrigger from '$lib/components/ui/accordion/accordion-trigger.svelte';
import AccordionContent from '$lib/components/ui/accordion/accordion-content.svelte';
import Progress from '$lib/components/ui/progress/progress.svelte';
import Sonner from '$lib/components/ui/sonner/sonner.svelte';
// TODO: Import Svelte stores for live data (agents, campaigns, cracked hashes, resource usage)
// TODO: Implement WebSocket connection for live updates
// TODO: Implement Agent Status Sheet logic
</script>

<div class="flex flex-col gap-y-6">
  <!-- Dashboard Cards Row -->
  <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
    <!-- Active Agents Card -->
    <Card>
      <CardHeader>
        <CardTitle>Active Agents</CardTitle>
      </CardHeader>
      <CardContent>
        <div class="flex items-center justify-between">
          <span class="text-3xl font-bold">0 / 0</span>
          <Badge color="success">Online</Badge>
        </div>
        <button class="mt-2 text-xs text-primary underline" on:click={() => {/* TODO: open agent sheet */}}>View Agents</button>
      </CardContent>
    </Card>
    <!-- Running Tasks Card -->
    <Card>
      <CardHeader>
        <CardTitle>Running Tasks</CardTitle>
      </CardHeader>
      <CardContent>
        <div class="flex items-center justify-between">
          <span class="text-3xl font-bold">0</span>
          <Badge color="secondary">0% Complete</Badge>
        </div>
      </CardContent>
    </Card>
    <!-- Recently Cracked Hashes Card -->
    <Card>
      <CardHeader>
        <CardTitle>Recently Cracked</CardTitle>
      </CardHeader>
      <CardContent>
        <div class="flex items-center justify-between">
          <span class="text-3xl font-bold">0</span>
          <!-- svelte-ignore a11y_invalid_attribute -->
          <a class="mt-2 text-xs text-primary underline" href="#">View All</a>
        </div>
      </CardContent>
    </Card>
    <!-- Resource Usage Card -->
    <Card>
      <CardHeader>
        <CardTitle>Resource Usage</CardTitle>
      </CardHeader>
      <CardContent>
        <!-- TODO: Insert sparkline/mini chart -->
        <div class="h-8 flex items-center justify-center text-muted">(Chart)</div>
      </CardContent>
    </Card>
  </div>

  <!-- Campaign Overview Section -->
  <section>
    <h2 class="text-xl font-semibold mb-2">Campaign Overview</h2>
    <!-- TODO: Replace with live campaign accordion -->
    <Accordion type="single">
      <AccordionItem value="sample-campaign">
        <AccordionTrigger>Sample Campaign</AccordionTrigger>
        <AccordionContent>
          <div class="flex flex-col gap-2">
            <Progress value={50} />
            <div class="flex items-center gap-2">
              <Badge color="primary">Running</Badge>
              <span>3 attacks / 1 running / ETA 3h</span>
            </div>
            <!-- TODO: List attacks, agents, etc. -->
          </div>
        </AccordionContent>
      </AccordionItem>
    </Accordion>
    <!-- TODO: Empty state if no campaigns -->
  </section>

  <!-- Toast notifications -->
  <Sonner />

  <!-- Agent Status Sheet (triggered by card/button) -->
  <!-- TODO: Implement AgentSheet and connect to store -->
</div>

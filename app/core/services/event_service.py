"""
Event broadcasting service for Server-Sent Events (SSE).

Provides in-memory event broadcasting with topic-based subscriptions
and project scoping for real-time notifications to the frontend.
"""

import asyncio
from collections.abc import AsyncGenerator
from datetime import UTC, datetime
from weakref import WeakSet

from loguru import logger
from pydantic import BaseModel


class EventMessage(BaseModel):
    """Standard event message format for SSE streams."""

    trigger: str = "refresh"
    timestamp: datetime
    target: str | None = None
    id: int | None = None
    project_id: int | None = None


class EventListener:
    """Represents an active SSE connection listening for events."""

    def __init__(self, topics: set[str], project_id: int | None = None) -> None:
        self.topics = topics
        self.project_id = project_id
        self.queue: asyncio.Queue[EventMessage] = asyncio.Queue(maxsize=100)
        self.active = True

    async def send_event(self, event: EventMessage) -> None:
        """Send an event to this listener if it matches topic/project filters."""
        if not self.active:
            return

        # Check if event matches any subscribed topics
        if event.target and event.target not in self.topics:
            return

        # Check project scoping
        if self.project_id is not None and event.project_id != self.project_id:
            return

        try:
            self.queue.put_nowait(event)
        except asyncio.QueueFull:
            logger.warning(f"Event queue full for listener, dropping event: {event}")

    async def get_events(self) -> AsyncGenerator[str]:
        """Generate SSE-formatted event strings."""
        try:
            while self.active:
                try:
                    # Wait for event with timeout to allow periodic cleanup
                    event = await asyncio.wait_for(self.queue.get(), timeout=30.0)

                    # Format as SSE event
                    event_data = event.model_dump_json()
                    yield f"data: {event_data}\n\n"

                except TimeoutError:
                    # Send keepalive ping
                    yield 'data: {"trigger": "ping"}\n\n'

        except asyncio.CancelledError:
            logger.debug("Event listener cancelled")
        finally:
            self.active = False


class EventService:
    """In-memory event broadcasting service for SSE streams."""

    def __init__(self) -> None:
        self._listeners: WeakSet[EventListener] = WeakSet()
        self._lock = asyncio.Lock()

    async def create_listener(
        self, topics: set[str], project_id: int | None = None
    ) -> EventListener:
        """Create a new event listener for the specified topics and project."""
        listener = EventListener(topics, project_id)

        async with self._lock:
            self._listeners.add(listener)

        logger.debug(
            f"Created event listener for topics {topics}, project {project_id}"
        )
        return listener

    async def broadcast_event(
        self,
        target: str,
        project_id: int | None = None,
        event_id: int | None = None,
        trigger: str = "refresh",
    ) -> None:
        """Broadcast an event to all matching listeners."""
        event = EventMessage(
            trigger=trigger,
            timestamp=datetime.now(UTC),
            target=target,
            id=event_id,
            project_id=project_id,
        )

        # Send to all matching listeners
        async with self._lock:
            tasks = [
                listener.send_event(event)
                for listener in list(self._listeners)
                if listener.active
            ]

        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
            logger.debug(f"Broadcasted {target} event to {len(tasks)} listeners")

    async def broadcast_campaign_update(
        self, campaign_id: int | None = None, project_id: int | None = None
    ) -> None:
        """Broadcast campaign state change event."""
        await self.broadcast_event(
            target="campaigns", project_id=project_id, event_id=campaign_id
        )

    async def broadcast_agent_update(
        self, agent_id: int | None = None, project_id: int | None = None
    ) -> None:
        """Broadcast agent state change event."""
        await self.broadcast_event(
            target="agents", project_id=project_id, event_id=agent_id
        )

    async def broadcast_toast_notification(
        self, message: str, project_id: int | None = None
    ) -> None:
        """Broadcast toast notification event."""
        await self.broadcast_event(
            target="toasts", project_id=project_id, trigger=message
        )

    def get_listener_count(self) -> int:
        """Get the current number of active listeners."""
        return len([listener for listener in self._listeners if listener.active])


# Global event service instance
class _EventServiceSingleton:
    """Singleton wrapper for the event service."""

    def __init__(self) -> None:
        self._instance: EventService | None = None

    def get_instance(self) -> EventService:
        """Get the singleton event service instance."""
        if self._instance is None:
            self._instance = EventService()
        return self._instance


_singleton = _EventServiceSingleton()


def get_event_service() -> EventService:
    """Get the global event service instance."""
    return _singleton.get_instance()

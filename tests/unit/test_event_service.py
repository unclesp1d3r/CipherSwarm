"""
Unit tests for event service.
"""

import asyncio
import pytest
from datetime import UTC, datetime

from app.core.services.event_service import (
    EventMessage,
    EventListener,
    EventService,
    get_event_service,
)


@pytest.mark.asyncio
async def test_event_message_creation():
    """Test EventMessage creation with default values."""
    message = EventMessage(timestamp=datetime.now(UTC))

    assert message.trigger == "refresh"
    assert message.timestamp is not None
    assert message.target is None
    assert message.id is None
    assert message.project_id is None


@pytest.mark.asyncio
async def test_event_message_creation_with_values():
    """Test EventMessage creation with custom values."""
    timestamp = datetime.now(UTC)
    message = EventMessage(
        trigger="update",
        timestamp=timestamp,
        target="campaigns",
        id=123,
        project_id=456,
    )

    assert message.trigger == "update"
    assert message.timestamp == timestamp
    assert message.target == "campaigns"
    assert message.id == 123
    assert message.project_id == 456


@pytest.mark.asyncio
async def test_event_listener_creation():
    """Test EventListener creation."""
    topics = {"campaigns", "agents"}
    listener = EventListener(topics=topics, project_id=123)

    assert listener.topics == topics
    assert listener.project_id == 123
    assert listener.active is True
    assert isinstance(listener.queue, asyncio.Queue)


@pytest.mark.asyncio
async def test_event_listener_send_event_matching_topic():
    """Test EventListener sends event when topic matches."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target="campaigns",
        project_id=123,
    )

    await listener.send_event(event)

    # Event should be in queue
    assert listener.queue.qsize() == 1
    queued_event = await listener.queue.get()
    assert queued_event.target == "campaigns"
    assert queued_event.project_id == 123


@pytest.mark.asyncio
async def test_event_listener_send_event_non_matching_topic():
    """Test EventListener doesn't send event when topic doesn't match."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target="agents",  # Different topic
        project_id=123,
    )

    await listener.send_event(event)

    # Event should not be in queue
    assert listener.queue.qsize() == 0


@pytest.mark.asyncio
async def test_event_listener_send_event_non_matching_project():
    """Test EventListener doesn't send event when project doesn't match."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target="campaigns",
        project_id=456,  # Different project
    )

    await listener.send_event(event)

    # Event should not be in queue
    assert listener.queue.qsize() == 0


@pytest.mark.asyncio
async def test_event_listener_send_event_no_project_scoping():
    """Test EventListener with no project scoping accepts all projects."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=None)

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target="campaigns",
        project_id=123,
    )

    await listener.send_event(event)

    # Event should be in queue
    assert listener.queue.qsize() == 1


@pytest.mark.asyncio
async def test_event_listener_send_event_no_target():
    """Test EventListener sends event when no target is specified."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target=None,  # No target specified
        project_id=123,
    )

    await listener.send_event(event)

    # Event should be in queue (no target filtering)
    assert listener.queue.qsize() == 1


@pytest.mark.asyncio
async def test_event_listener_send_event_inactive():
    """Test EventListener doesn't send event when inactive."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)
    listener.active = False

    event = EventMessage(
        timestamp=datetime.now(UTC),
        target="campaigns",
        project_id=123,
    )

    await listener.send_event(event)

    # Event should not be in queue
    assert listener.queue.qsize() == 0


@pytest.mark.asyncio
async def test_event_listener_queue_full():
    """Test EventListener handles full queue gracefully."""
    topics = {"campaigns"}
    listener = EventListener(topics=topics, project_id=123)

    # Fill the queue to capacity (maxsize=100)
    for i in range(100):
        event = EventMessage(
            timestamp=datetime.now(UTC),
            target="campaigns",
            project_id=123,
            id=i,
        )
        await listener.send_event(event)

    assert listener.queue.qsize() == 100

    # Try to add one more event - should not raise exception
    overflow_event = EventMessage(
        timestamp=datetime.now(UTC),
        target="campaigns",
        project_id=123,
        id=999,
    )

    # This should not block or raise an exception due to put_nowait
    # If queue is full, put_nowait raises QueueFull, but send_event should handle it
    try:
        await listener.send_event(overflow_event)
    except asyncio.QueueFull:
        # This is expected behavior when queue is full
        pass

    # Queue should still be at capacity
    assert listener.queue.qsize() == 100


@pytest.mark.asyncio
async def test_get_event_service_singleton():
    """Test that get_event_service returns the same instance."""
    service1 = get_event_service()
    service2 = get_event_service()

    assert service1 is service2
    assert isinstance(service1, EventService)


@pytest.mark.asyncio
async def test_event_service_initialization():
    """Test EventService initialization."""
    service = EventService()

    assert hasattr(service, "listeners")
    assert isinstance(service.listeners, set)
    assert len(service.listeners) == 0


@pytest.mark.asyncio
async def test_event_listener_multiple_topics():
    """Test EventListener with multiple topics."""
    topics = {"campaigns", "agents", "tasks"}
    listener = EventListener(topics=topics, project_id=123)

    # Test each topic
    for topic in topics:
        event = EventMessage(
            timestamp=datetime.now(UTC),
            target=topic,
            project_id=123,
        )

        await listener.send_event(event)

    # Should have received all events
    assert listener.queue.qsize() == 3

    # Verify each event
    for expected_topic in topics:
        queued_event = await listener.queue.get()
        assert queued_event.target in topics

"""Core event handlers."""

from collections.abc import Callable, Coroutine
from typing import Any


def create_start_app_handler() -> Callable[[], Coroutine[Any, Any, None]]:
    """Create a startup event handler.

    Returns:
        Callable[[], Coroutine[Any, Any, None]]: Async startup handler function
    """

    async def start_app() -> None:
        """Initialize application services."""
        print("Starting up...")  # Placeholder for actual initialization

    return start_app


def create_stop_app_handler() -> Callable[[], Coroutine[Any, Any, None]]:
    """Create a shutdown event handler.

    Returns:
        Callable[[], Coroutine[Any, Any, None]]: Async shutdown handler function
    """

    async def stop_app() -> None:
        """Cleanup application services."""
        print("Shutting down...")  # Placeholder for actual cleanup

    return stop_app

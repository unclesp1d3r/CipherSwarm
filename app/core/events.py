"""Core event handlers."""

from collections.abc import Callable, Coroutine
from typing import Any

from app.core.config import settings
from app.db.config import DatabaseSettings
from app.db.session import sessionmanager


def create_start_app_handler() -> Callable[[], Coroutine[Any, Any, None]]:
    """Create a startup event handler.

    Returns:
        Callable[[], Coroutine[Any, Any, None]]: Async startup handler function
    """

    async def start_app() -> None:
        """Initialize application services."""
        # Initialize the global database session manager
        db_settings = DatabaseSettings(
            url=settings.sqlalchemy_database_uri,
            # Optionally, add more settings here if needed
        )
        sessionmanager.init(db_settings)

    return start_app


def create_stop_app_handler() -> Callable[[], Coroutine[Any, Any, None]]:
    """Create a shutdown event handler.

    Returns:
        Callable[[], Coroutine[Any, Any, None]]: Async shutdown handler function
    """

    async def stop_app() -> None:
        """Cleanup application services."""
        # Clean up the global database session manager
        await sessionmanager.close()

    return stop_app

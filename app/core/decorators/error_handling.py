"""
Error handling decorators for consistent API error responses.

This module provides decorators that standardize error handling across
API endpoints, reducing code duplication and ensuring consistent error responses.
"""

import functools
import inspect
import logging
from collections.abc import Callable
from typing import Any, ParamSpec, TypeVar

from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

P = ParamSpec("P")
T = TypeVar("T")


def handle_service_errors(func: Callable[P, T]) -> Callable[P, Any]:  # noqa: UP047
    """
    Decorator for consistent error handling in service calls.

    This decorator provides standardized error handling for service layer calls,
    converting domain exceptions to appropriate HTTP exceptions with consistent
    error messages and logging.

    Args:
        func: The function to wrap with error handling

    Returns:
        Wrapped function with error handling

    Example:
        @handle_service_errors
        async def register_agent(...):
            return await agent_service.register(...)
    """

    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> Any:  # noqa: ANN401
        try:
            result = func(*args, **kwargs)
            if inspect.isawaitable(result):
                return result
            return result  # noqa: TRY300
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
            ) from e
        except Exception as e:
            # Unexpected errors
            logger.exception(f"Unexpected error in {func.__name__}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error",
            ) from e

    return wrapper


def handle_agent_errors(func: Callable[P, T]) -> Callable[P, Any]:  # noqa: UP047
    """
    Decorator for agent-specific error handling.

    This decorator provides error handling specific to agent operations,
    including authentication and authorization errors.

    Args:
        func: The function to wrap with error handling

    Returns:
        Wrapped function with error handling
    """

    @functools.wraps(func)
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> Any:  # noqa: ANN401
        try:
            result = func(*args, **kwargs)
            if inspect.isawaitable(result):
                return result
            return result  # noqa: TRY300
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Agent validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
            ) from e
        except Exception as e:
            # Unexpected errors
            logger.exception(f"Unexpected agent error in {func.__name__}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Agent operation failed",
            ) from e

    return wrapper

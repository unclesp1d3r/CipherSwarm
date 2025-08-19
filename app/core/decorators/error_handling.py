"""
Error handling decorators for consistent API error responses.

This module provides decorators that standardize error handling across
API endpoints, reducing code duplication and ensuring consistent error responses.
"""

import functools
import logging
from collections.abc import Callable
from typing import ParamSpec, TypeVar

from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

P = ParamSpec("P")
T = TypeVar("T")


def handle_service_errors(func: Callable[P, T]) -> Callable[P, T]:
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
    async def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
        try:
            return await func(*args, **kwargs)
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e)
            )
        except Exception as e:
            # Unexpected errors
            logger.error(
                f"Unexpected error in {func.__name__}: {e!s}",
                exc_info=True
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error"
            )
    return wrapper


def handle_agent_errors(func: Callable[P, T]) -> Callable[P, T]:
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
    async def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
        try:
            return await func(*args, **kwargs)
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Agent validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(e)
            )
        except Exception as e:
            # Unexpected errors
            logger.error(
                f"Unexpected agent error in {func.__name__}: {e!s}",
                exc_info=True
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Agent operation failed"
            )
    return wrapper

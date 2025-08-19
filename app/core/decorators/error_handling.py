"""
Error handling decorators for consistent API error responses.

This module provides decorators that standardize error handling across
API endpoints, reducing code duplication and ensuring consistent error responses.
"""

import functools
import inspect
from collections.abc import Callable
from typing import Any, ParamSpec, TypeVar

from fastapi import HTTPException, status
from fastapi.responses import JSONResponse
from loguru import logger

from app.core.exceptions import (
    AgentAlreadyExistsError,
    AgentNotFoundError,
    InvalidAgentStateError,
    InvalidAgentTokenError,
    ResourceNotFoundError,
)

P = ParamSpec("P")
T = TypeVar("T")

# Domain exception to HTTP status code mapping
DOMAIN_EXCEPTION_MAPPING = {
    AgentNotFoundError: status.HTTP_404_NOT_FOUND,
    ResourceNotFoundError: status.HTTP_404_NOT_FOUND,
    InvalidAgentTokenError: status.HTTP_401_UNAUTHORIZED,
    AgentAlreadyExistsError: status.HTTP_409_CONFLICT,
    InvalidAgentStateError: status.HTTP_422_UNPROCESSABLE_ENTITY,
}


def handle_service_errors(func: Callable[P, T]) -> Any:  # noqa: UP047, ANN401
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
    if inspect.iscoroutinefunction(func):

        @functools.wraps(func)
        async def async_wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions immediately to preserve status codes and context
                raise
            except ValueError as e:
                # Business logic validation errors
                logger.warning(f"Validation error in {func.__name__}: {e!s}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
                ) from e
            except tuple(DOMAIN_EXCEPTION_MAPPING.keys()) as e:
                # Domain-specific exceptions with proper status code mapping
                status_code = DOMAIN_EXCEPTION_MAPPING[type(e)]
                logger.warning(
                    f"Domain error in {func.__name__}: {type(e).__name__}: {e!s}"
                )
                # Add WWW-Authenticate header for 401 responses
                headers = (
                    {"WWW-Authenticate": "Bearer"}
                    if status_code == status.HTTP_401_UNAUTHORIZED
                    else None
                )
                raise HTTPException(
                    status_code=status_code, detail=str(e), headers=headers
                ) from e
            except Exception as e:
                # Unexpected errors
                logger.exception(f"Unexpected error in {func.__name__}")
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail="Internal server error",
                ) from e

        return async_wrapper

    @functools.wraps(func)
    def sync_wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
        try:
            return func(*args, **kwargs)
        except HTTPException:
            # Re-raise HTTPExceptions immediately to preserve status codes and context
            raise
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
            ) from e
        except tuple(DOMAIN_EXCEPTION_MAPPING.keys()) as e:
            # Domain-specific exceptions with proper status code mapping
            status_code = DOMAIN_EXCEPTION_MAPPING[type(e)]
            logger.warning(
                f"Domain error in {func.__name__}: {type(e).__name__}: {e!s}"
            )
            # Add WWW-Authenticate header for 401 responses
            headers = (
                {"WWW-Authenticate": "Bearer"}
                if status_code == status.HTTP_401_UNAUTHORIZED
                else None
            )
            raise HTTPException(
                status_code=status_code, detail=str(e), headers=headers
            ) from e
        except Exception as e:
            # Unexpected errors
            logger.exception(f"Unexpected error in {func.__name__}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Internal server error",
            ) from e

    return sync_wrapper


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
    if inspect.iscoroutinefunction(func):

        @functools.wraps(func)
        async def async_wrapper(*args: P.args, **kwargs: P.kwargs) -> Any:  # noqa: ANN401
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                # Re-raise HTTPExceptions immediately to preserve status codes and context
                raise
            except ValueError as e:
                # Business logic validation errors
                logger.warning(f"Agent validation error in {func.__name__}: {e!s}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
                ) from e
            except tuple(DOMAIN_EXCEPTION_MAPPING.keys()) as e:
                # Domain-specific exceptions with proper status code mapping
                status_code = DOMAIN_EXCEPTION_MAPPING[type(e)]
                logger.warning(
                    f"Agent domain error in {func.__name__}: {type(e).__name__}: {e!s}"
                )
                # Add WWW-Authenticate header for 401 responses
                headers = (
                    {"WWW-Authenticate": "Bearer"}
                    if status_code == status.HTTP_401_UNAUTHORIZED
                    else None
                )
                raise HTTPException(
                    status_code=status_code, detail=str(e), headers=headers
                ) from e
            except Exception:  # noqa: BLE001 - intentional catch-all for v2 envelope
                # Unexpected errors - return v2 envelope directly for agent API v2 compatibility
                logger.exception(f"Unexpected agent error in {func.__name__}")
                from datetime import UTC, datetime

                return JSONResponse(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    content={
                        "error": "internal_server_error",
                        "message": "An unexpected error occurred",
                        "details": None,
                        "timestamp": datetime.now(UTC).isoformat(),
                    },
                )

        return async_wrapper

    @functools.wraps(func)
    def sync_wrapper(*args: P.args, **kwargs: P.kwargs) -> Any:  # noqa: ANN401
        try:
            return func(*args, **kwargs)
        except HTTPException:
            # Re-raise HTTPExceptions immediately to preserve status codes and context
            raise
        except ValueError as e:
            # Business logic validation errors
            logger.warning(f"Agent validation error in {func.__name__}: {e!s}")
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
            ) from e
        except tuple(DOMAIN_EXCEPTION_MAPPING.keys()) as e:
            # Domain-specific exceptions with proper status code mapping
            status_code = DOMAIN_EXCEPTION_MAPPING[type(e)]
            logger.warning(
                f"Agent domain error in {func.__name__}: {type(e).__name__}: {e!s}"
            )
            # Add WWW-Authenticate header for 401 responses
            headers = (
                {"WWW-Authenticate": "Bearer"}
                if status_code == status.HTTP_401_UNAUTHORIZED
                else None
            )
            raise HTTPException(
                status_code=status_code, detail=str(e), headers=headers
            ) from e
        except Exception:  # noqa: BLE001 - intentional catch-all for v2 envelope
            # Unexpected errors - return v2 envelope directly for agent API v2 compatibility
            logger.exception(f"Unexpected agent error in {func.__name__}")
            from datetime import UTC, datetime

            return JSONResponse(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                content={
                    "error": "internal_server_error",
                    "message": "An unexpected error occurred",
                    "details": None,
                    "timestamp": datetime.now(UTC).isoformat(),
                },
            )

    return sync_wrapper

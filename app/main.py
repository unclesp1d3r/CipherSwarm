"""CipherSwarm FastAPI Application."""

import logging
import time
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.api.v2.router import api_router as v2_api_router
from app.core.config import settings
from app.core.events import create_start_app_handler, create_stop_app_handler
from app.core.exceptions import InvalidAgentTokenError
from app.core.logging import logger


# Redirect standard logging to loguru
class InterceptHandler(logging.Handler):
    def emit(self, record: logging.LogRecord) -> None:
        # Get corresponding Loguru level if it exists
        try:
            level = logger.level(record.levelname).name
        except ValueError:
            level = str(record.levelno)
        frame = logging.currentframe()
        depth = 2
        while frame and frame.f_code.co_filename == logging.__file__:
            frame = frame.f_back  # type: ignore[assignment]
            depth += 1
        logger.opt(depth=depth, exception=record.exc_info).log(
            level, record.getMessage()
        )


logging.basicConfig(handlers=[InterceptHandler()], level=0)
for name in logging.root.manager.loggerDict:
    logging.getLogger(name).handlers = [InterceptHandler()]


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None]:
    """FastAPI lifespan events."""
    start_app = create_start_app_handler()
    stop_app = create_stop_app_handler()

    await start_app()
    yield
    await stop_app()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="The CipherSwarm Agent API is used to allow agents to connect to the CipherSwarm server.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)


# Logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next: Any) -> Any:
    start_time = time.time()
    request_id = request.headers.get("x-request-id")
    try:
        response = await call_next(request)
    except Exception:
        logger.exception(
            f"Exception in request: {request.method} {request.url.path} | request_id={request_id}"
        )
        raise
    process_time = (time.time() - start_time) * 1000
    logger.info(
        f"{request.method} {request.url.path} - {response.status_code} - {process_time:.2f}ms | request_id={request_id}"
    )
    return response


app.include_router(api_router, prefix=settings.API_V1_STR)
app.include_router(v2_api_router, prefix="/api/v2")


@app.get("/")
async def root() -> dict[str, str]:
    """Root endpoint.

    Returns:
        dict[str, str]: Basic API information
    """
    return {
        "name": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
        "redoc": "/redoc",
    }


@app.exception_handler(InvalidAgentTokenError)
async def invalid_agent_token_handler(exc: InvalidAgentTokenError) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


def run_server() -> None:
    """Run the FastAPI server with development configuration."""
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",  # noqa: S104
        port=8000,
        reload=True,
    )

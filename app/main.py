"""CipherSwarm FastAPI Application."""

import logging
import time
from collections.abc import AsyncGenerator, Awaitable, Callable
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router, v1_http_exception_handler
from app.core.config import settings
from app.core.events import create_start_app_handler, create_stop_app_handler
from app.core.exceptions import InvalidAgentTokenError
from app.core.logging import logger
from app.web.web_router import web_router


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


# Register v1 error envelope handler for HTTPException
app.add_exception_handler(HTTPException, v1_http_exception_handler)


# Logging middleware
@app.middleware("http")
async def log_requests(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    start_time = time.time()
    request_id = request.headers.get("x-request-id")
    try:
        response = await call_next(request)
    except Exception as e:
        logger.error(
            "Exception in request: {method} {url} | request_id={request_id} | error={error}",
            method=request.method,
            url=request.url.path,
            request_id=request_id,
            error=str(e),
        )
        raise
    process_time = (time.time() - start_time) * 1000
    logger.info(
        "{method} {url} - {status_code} - {process_time:.2f}ms | request_id={request_id}",
        method=request.method,
        url=request.url.path,
        status_code=response.status_code,
        process_time=process_time,
        request_id=request_id,
    )
    return response


app.include_router(api_router, prefix=settings.API_V1_STR)
# v2 API router registration removed as part of v2 Agent API removal and v1 decoupling (see v2_agent_api_removal.md)
app.include_router(web_router)


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
async def invalid_agent_token_handler(
    _request: Request, exc: InvalidAgentTokenError
) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


def run_server() -> None:
    """Run the FastAPI server with development configuration."""
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",  # noqa: S104
        port=8000,
        reload=True,
    )

"""CipherSwarm FastAPI Application."""

import logging
import time
from collections.abc import AsyncGenerator, Awaitable, Callable
from contextlib import asynccontextmanager

import uvicorn
from cashews import cache
from cashews.contrib.fastapi import (
    CacheDeleteMiddleware,
    CacheEtagMiddleware,
    CacheRequestControlMiddleware,
)
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.v1.endpoints.agent.v1_http_exception_handler import (
    v1_http_exception_handler,
)
from app.api.v1.router import api_router as api_v1_router
from app.core.config import settings
from app.core.control_rfc9457_middleware import ControlRFC9457Middleware
from app.core.exceptions import InvalidAgentTokenError
from app.core.logging import logger
from app.db.config import DatabaseSettings
from app.db.session import sessionmanager


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
    # Initialize database session manager
    db_settings = DatabaseSettings(
        url=settings.sqlalchemy_database_uri,
        echo=False,  # Set to True for SQL debugging
    )
    sessionmanager.init(db_settings)

    yield

    # Cleanup on shutdown
    await sessionmanager.close()


app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="The CipherSwarm Agent API is used to allow agents to connect to the CipherSwarm server.",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Add Cashews Middleware
app.add_middleware(CacheDeleteMiddleware)
app.add_middleware(CacheEtagMiddleware)
app.add_middleware(CacheRequestControlMiddleware)
cache.setup(settings.CACHE_CONNECT_STRING)

app.add_middleware(
    GZipMiddleware, minimum_size=1000
)  # Compress responses larger than 1000 bytes


# Add RFC9457 middleware for Control API routes only
app.add_middleware(ControlRFC9457Middleware)

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


# Middleware to set cookies from request.state.set_cookie (for FastHX endpoints)
@app.middleware("http")
async def set_cookie_from_state_middleware(
    request: Request, call_next: Callable[[Request], Awaitable[Response]]
) -> Response:
    response = await call_next(request)
    set_cookie = getattr(request.state, "set_cookie", None)
    if set_cookie:
        response.set_cookie(**set_cookie)
    hx_status_code = getattr(request.state, "hx_status_code", None)
    if hx_status_code:
        response.status_code = hx_status_code
    return response


# v1 API router registration
app.include_router(api_v1_router, prefix="/api/v1")
# v2 API router registration removed as part of v2 Agent API removal and v1 decoupling (see v2_agent_api_removal.md)
# app.include_router(api_v2_router, prefix="/api/v2")

# Web router registration
app.mount("/", StaticFiles(directory="frontend/build", html=True), name="frontend")


# This should return the static HTML for the web UI
# Removed @app.get("/") to allow dashboard HTML to be served at root


@app.get("/api-info")
async def api_info() -> dict[str, str]:
    """API information stub (moved from root)."""
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


# Register v1 error handler for all /api/v1/client/* and /api/v1/agent/* endpoints (contract compliance)
# The handler passes any non-Agent API endpoints to the default handler
app.add_exception_handler(HTTPException, v1_http_exception_handler)


def run_server() -> None:
    """Run the FastAPI server with development configuration."""
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",  # noqa: S104
        port=8000,
        reload=True,
    )

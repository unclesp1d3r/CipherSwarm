"""CipherSwarm FastAPI Application."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse

from app.api.v1.router import api_router
from app.api.v2.router import api_router as v2_api_router
from app.core.config import settings
from app.core.events import create_start_app_handler, create_stop_app_handler
from app.core.exceptions import InvalidAgentTokenError


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

"""CipherSwarm FastAPI Application."""

from contextlib import asynccontextmanager
from typing import AsyncGenerator

import uvicorn
from fastapi import FastAPI

from app.core.config import settings
from app.core.events import create_start_app_handler, create_stop_app_handler


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
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


def run_server() -> None:
    """Run the FastAPI server with development configuration."""
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )

import sys

from loguru import logger

from app.core.config import settings

__all__ = ["logger"]

LOG_FORMAT = (
    "{time:YYYY-MM-DD HH:mm:ss} | {level} | {module}:{function}:{line} - {message}"
)

logger.remove()
logger.add(
    sys.stderr,
    level=settings.log_level,
    format=LOG_FORMAT,
    enqueue=True,
    backtrace=True,
    diagnose=True,
)

if settings.log_to_file:
    logger.add(
        settings.log_file_path,
        level=settings.log_level,
        format=LOG_FORMAT,
        rotation=settings.log_rotation,
        retention=settings.log_retention,
        enqueue=True,
        backtrace=True,
        diagnose=True,
    )

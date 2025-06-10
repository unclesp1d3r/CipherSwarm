"""
Pagination utilities for Control API.

Note: These utilities are primarily for backward compatibility.
New service functions should implement offset-based pagination directly
using the *_service_offset variants to avoid conversion overhead.
"""

from warnings import deprecated


@deprecated("Use page_to_offset_conversion instead")
def web_to_control_pagination(page: int, page_size: int) -> tuple[int, int]:
    return page_to_offset_conversion(page, page_size)


def page_to_offset_conversion(page: int, page_size: int) -> tuple[int, int]:
    """Convert page-based to offset-based pagination."""
    offset = (page - 1) * page_size
    limit = page_size
    return offset, limit


@deprecated("Use control_to_web_pagination instead")
def control_to_web_pagination(offset: int, limit: int) -> tuple[int, int]:
    return offset_to_page_conversion(offset, limit)


def offset_to_page_conversion(offset: int, limit: int) -> tuple[int, int]:
    """Convert offset-based to page-based pagination."""
    page = (offset // limit) + 1 if limit > 0 else 1
    page_size = limit
    return page, page_size

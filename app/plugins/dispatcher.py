import importlib
from collections.abc import Callable
from pathlib import Path
from types import ModuleType
from typing import cast

from app.core.exceptions import PluginExecutionError
from app.models.raw_hash import RawHash


def get_plugin_module(extension: str) -> ModuleType:
    """Return the plugin module for a given file extension."""
    ext = extension.lower().lstrip(".")
    plugin_map = {
        "shadow": "app.plugins.shadow_plugin",
        # Add more mappings as new plugins are implemented
    }
    module_name = plugin_map.get(ext)
    if not module_name:
        raise PluginExecutionError(f"No plugin registered for extension: {extension}")
    try:
        return importlib.import_module(module_name)
    except Exception as e:
        raise PluginExecutionError(
            f"Failed to import plugin '{module_name}': {e}"
        ) from e


def get_extract_hashes_func(module: ModuleType) -> Callable[[Path, int], list[RawHash]]:
    func = getattr(module, "extract_hashes", None)
    if not callable(func):
        raise PluginExecutionError(
            f"Plugin '{module.__name__}' does not implement extract_hashes()"
        )
    return cast("Callable[[Path, int], list[RawHash]]", func)


def dispatch_extract_hashes(
    path: Path, extension: str, upload_task_id: int
) -> list[RawHash]:
    """
    Load the appropriate plugin for the given extension and call extract_hashes(path, upload_task_id).
    Raises PluginExecutionError on failure.
    """
    module = get_plugin_module(extension)
    extract_hashes = get_extract_hashes_func(module)
    try:
        return extract_hashes(path, upload_task_id)
    except Exception as e:
        raise PluginExecutionError(f"Plugin '{module.__name__}' failed: {e}") from e

# pyright: ignore[reportAttributeAccessIssue]
import sys
import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest

from app.core.exceptions import PluginExecutionError
from app.models.raw_hash import RawHash
from app.plugins import dispatcher, shadow_plugin


@pytest.fixture
def sample_shadow_file() -> Generator[Path]:
    content = """
root:$6$saltsalt$abcdefghijklmnopqrstuvwx:19000:0:99999:7:::
user1:$6$othersalt$zyxwvutsrqponmlkjihgfedcba:19001:0:99999:7:::
# comment line
badline
"""
    with tempfile.NamedTemporaryFile("w+", delete=False) as f:
        f.write(content)
        f.flush()
        yield Path(f.name)
    Path(f.name).unlink()


def test_extract_hashes_basic(sample_shadow_file: Path) -> None:
    hashes = shadow_plugin.extract_hashes(sample_shadow_file, upload_task_id=42)
    assert len(hashes) == 2
    assert all(isinstance(h, RawHash) for h in hashes)
    assert hashes[0].username == "root"
    assert hashes[1].username == "user1"
    assert hashes[0].hash.startswith("$6$")
    assert hashes[1].hash.startswith("$6$")
    assert hashes[0].line_number == 2
    assert hashes[1].line_number == 3
    assert hashes[0].upload_task_id == 42
    assert hashes[1].upload_task_id == 42
    # Hash type guessing should default to 1800 (sha512crypt) or use guess
    assert isinstance(hashes[0].hash_type_id, int)
    assert isinstance(hashes[1].hash_type_id, int)


def test_dispatcher_success(sample_shadow_file: Path) -> None:
    hashes = dispatcher.dispatch_extract_hashes(
        sample_shadow_file, "shadow", upload_task_id=99
    )
    assert len(hashes) == 2
    assert all(isinstance(h, RawHash) for h in hashes)
    assert hashes[0].upload_task_id == 99
    assert hashes[1].upload_task_id == 99


def test_dispatcher_missing_plugin(sample_shadow_file: Path) -> None:
    with pytest.raises(PluginExecutionError) as exc:
        dispatcher.dispatch_extract_hashes(
            sample_shadow_file, "notreal", upload_task_id=1
        )
    assert "No plugin registered for extension" in str(exc.value)


def test_dispatcher_missing_extract_hashes(
    monkeypatch: pytest.MonkeyPatch, sample_shadow_file: Path
) -> None:
    # Dynamically create a dummy plugin module without extract_hashes
    import types

    dummy_mod = types.ModuleType("dummy_plugin")
    sys.modules["app.plugins.dummy_plugin"] = dummy_mod
    monkeypatch.setattr(dispatcher, "get_plugin_module", lambda _: dummy_mod)
    with pytest.raises(PluginExecutionError) as exc:
        dispatcher.dispatch_extract_hashes(
            sample_shadow_file, "dummy", upload_task_id=1
        )
    assert "does not implement extract_hashes" in str(exc.value)


def test_dispatcher_plugin_execution_error(
    monkeypatch: pytest.MonkeyPatch, sample_shadow_file: Path
) -> None:
    # Dummy plugin with extract_hashes that raises
    import types

    def bad_extract_hashes(*args: object, **kwargs: object) -> None:
        raise RuntimeError("fail inside plugin")

    dummy_mod = types.ModuleType("bad_plugin")
    dummy_mod.extract_hashes = bad_extract_hashes  # type: ignore[attr-defined, unused-ignore]
    sys.modules["app.plugins.bad_plugin"] = dummy_mod
    monkeypatch.setattr(dispatcher, "get_plugin_module", lambda _: dummy_mod)
    with pytest.raises(PluginExecutionError) as exc:
        dispatcher.dispatch_extract_hashes(sample_shadow_file, "bad", upload_task_id=1)
    assert "failed" in str(exc.value)
    assert "fail inside plugin" in str(exc.value)

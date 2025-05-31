import tempfile
from collections.abc import Generator
from pathlib import Path

import pytest

from app.models.raw_hash import RawHash
from app.plugins import shadow_plugin


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

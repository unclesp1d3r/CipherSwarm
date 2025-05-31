from pathlib import Path

import pytest

from app.plugins import base


def test_extract_hashes_not_implemented() -> None:
    with pytest.raises(NotImplementedError):
        base.extract_hashes(Path("/tmp/fakefile"))

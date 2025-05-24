from unittest.mock import patch

from app.core.services.hash_guess_service import HashGuessService


def test_normalize_input_basic() -> None:
    raw = "user1:$6$saltsalt$abcdefg\nuser2:$6$saltsalt$hijklmn\n\n"
    lines = HashGuessService.normalize_input(raw)
    assert lines == ["$6$saltsalt$abcdefg", "$6$saltsalt$hijklmn"]


def test_normalize_input_handles_colons() -> None:
    raw = "admin:$1$xyz$hashvalue:extra\nfoo:bar:baz:hashonly"
    lines = HashGuessService.normalize_input(raw)
    assert lines == ["$1$xyz$hashvalue:extra", "bar:baz:hashonly"]


def test_guess_hash_types_returns_candidates() -> None:
    # Use a real hash that Name-That-Hash recognizes
    candidates = HashGuessService.guess_hash_types("5f4dcc3b5aa765d61d8327deb882cf99")
    # Should include MD5 (hashcat 0) and possibly others
    assert any(c.hash_type == 0 and c.name == "MD5" for c in candidates)
    assert all(isinstance(c.confidence, float) for c in candidates)


def test_guess_hash_types_dedupes_and_ranks() -> None:
    # Use two identical hashes to check deduplication
    candidates = HashGuessService.guess_hash_types(
        "5f4dcc3b5aa765d61d8327deb882cf99\n5f4dcc3b5aa765d61d8327deb882cf99"
    )
    # Should not duplicate MD5
    md5s = [c for c in candidates if c.hash_type == 0 and c.name == "MD5"]
    assert len(md5s) == 1


def test_guess_hash_types_empty_input() -> None:
    candidates = HashGuessService.guess_hash_types("")
    assert candidates == []


def test_guess_hash_types_handles_runner_error() -> None:
    with patch(
        "app.core.services.hash_guess_service.runner.api_return_hashes_as_dict",
        side_effect=Exception("fail"),
    ):
        candidates = HashGuessService.guess_hash_types(
            "5f4dcc3b5aa765d61d8327deb882cf99"
        )
        assert candidates == []


def test_guess_hash_types_output_format() -> None:
    candidates = HashGuessService.guess_hash_types("5f4dcc3b5aa765d61d8327deb882cf99")
    d = candidates[0].model_dump()
    assert set(d.keys()) == {"hash_type", "name", "confidence"}
    assert isinstance(d["hash_type"], int)
    assert isinstance(d["name"], str)
    assert isinstance(d["confidence"], float)

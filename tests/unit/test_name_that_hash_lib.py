import pytest

try:
    from name_that_hash import runner  # type: ignore[import-untyped]
except ImportError:
    runner = None


def test_name_that_hash_valid_md5() -> None:
    if runner is None:
        pytest.skip("name-that-hash is not installed")
    md5_hash = ["5f4dcc3b5aa765d61d8327deb882cf99"]
    result = runner.api_return_hashes_as_dict(md5_hash, {"popular_only": False})
    assert "5f4dcc3b5aa765d61d8327deb882cf99" in result
    candidates = result["5f4dcc3b5aa765d61d8327deb882cf99"]
    assert any(c.get("name") == "MD5" for c in candidates)


def test_name_that_hash_empty_string() -> None:
    if runner is None:
        pytest.skip("name-that-hash is not installed")
    bad_input = [""]
    result = runner.api_return_hashes_as_dict(bad_input, {"popular_only": False})
    assert result == {"": []}


def test_name_that_hash_garbage_input() -> None:
    if runner is None:
        pytest.skip("name-that-hash is not installed")
    garbage = ["notahash!@#$%^&*"]
    result = runner.api_return_hashes_as_dict(garbage, {"popular_only": False})
    print(f"Garbage input result: {result}")
    assert "notahash!@#$%^&*" in result
    # It may return an empty list or some guess, so just check the key exists


def test_name_that_hash_binary_like_input() -> None:
    if runner is None:
        pytest.skip("name-that-hash is not installed")
    binary_like = ["\x00\x01\x02\x03\x04"]
    result = runner.api_return_hashes_as_dict(binary_like, {"popular_only": False})
    print(f"Binary-like input result: {result}")
    assert "\x00\x01\x02\x03\x04" in result
    # It may return an empty list or some guess, so just check the key exists

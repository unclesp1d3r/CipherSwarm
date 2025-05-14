import httpx
import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_estimate_attack_happy_path(async_client: AsyncClient) -> None:
    payload = {
        "name": "Test Attack",
        "hash_type_id": 0,
        "attack_mode": "dictionary",
        "hash_list_id": 1,
        "hash_list_url": "http://example.com/hashes.txt",
        "hash_list_checksum": "deadbeef",
    }
    resp = await async_client.post("/api/v1/web/attacks/estimate", json=payload)
    assert resp.status_code == httpx.codes.OK
    assert "Keyspace Estimate" in resp.text
    assert "Complexity Score" in resp.text


@pytest.mark.asyncio
async def test_estimate_attack_invalid_input(async_client: AsyncClient) -> None:
    # Missing required fields
    payload = {"name": "Incomplete Attack"}
    resp = await async_client.post("/api/v1/web/attacks/estimate", json=payload)
    assert resp.status_code == httpx.codes.BAD_REQUEST
    assert "error" in resp.text or "message" in resp.text


@pytest.mark.asyncio
async def test_estimate_attack_non_json(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/estimate",
        content=b"notjson",
        headers={"Content-Type": "application/json"},
    )
    assert resp.status_code in (httpx.codes.BAD_REQUEST, 422)

import pytest
from httpx import AsyncClient

HTTP_200_OK = 200


@pytest.mark.asyncio
async def test_dashboard_root_route_returns_html(async_client: AsyncClient) -> None:
    resp = await async_client.get("/")
    assert resp.status_code == HTTP_200_OK
    # Should return HTML, not JSON
    assert resp.headers["content-type"].startswith("text/html")
    # Should contain a dashboard marker (e.g., title or known element)
    assert "dashboard" in resp.text.lower() or "cipherswarm" in resp.text.lower()


@pytest.mark.asyncio
async def test_web_hash_guess_valid_md5(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/hash_guess",
        data={"hash_material": "5f4dcc3b5aa765d61d8327deb882cf99"},
    )
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert "candidates" in data
    assert any(c["name"] == "MD5" for c in data["candidates"])


@pytest.mark.asyncio
async def test_web_hash_guess_empty(async_client: AsyncClient) -> None:
    resp = await async_client.post("/api/v1/web/hash_guess", data={"hash_material": ""})
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert data["candidates"] == []


@pytest.mark.asyncio
async def test_web_hash_guess_garbage(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/hash_guess", data={"hash_material": "notahash!@#$%^&*"}
    )
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert "candidates" in data
    # May be empty or contain guesses, just check structure


@pytest.mark.asyncio
async def test_web_hash_guess_binary_like(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/hash_guess", data={"hash_material": "\x00\x01\x02\x03\x04"}
    )
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert "candidates" in data
    # May be empty or contain guesses, just check structure

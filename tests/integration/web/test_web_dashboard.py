import pytest
from httpx import AsyncClient, codes


@pytest.mark.asyncio
async def test_dashboard_summary_returns_expected_fields(
    async_client: AsyncClient,
) -> None:
    response = await async_client.get("/api/v1/web/dashboard/summary")
    assert response.status_code == codes.OK
    data = response.json()
    assert set(data.keys()) == {
        "active_agents",
        "total_agents",
        "running_tasks",
        "total_tasks",
        "recently_cracked_hashes",
        "resource_usage",
    }
    assert isinstance(data["active_agents"], int)
    assert isinstance(data["total_agents"], int)
    assert isinstance(data["running_tasks"], int)
    assert isinstance(data["total_tasks"], int)
    assert isinstance(data["recently_cracked_hashes"], int)
    assert isinstance(data["resource_usage"], list)
    if data["resource_usage"]:
        point = data["resource_usage"][0]
        assert "timestamp" in point
        assert "hash_rate" in point

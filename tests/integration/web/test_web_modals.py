import pytest
from httpx import AsyncClient, codes


@pytest.mark.asyncio
async def test_rule_explanation_modal_json(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/modals/rule_explanation")
    assert resp.status_code == codes.OK
    data = resp.json()
    assert "rule_explanations" in data
    assert isinstance(data["rule_explanations"], list)
    # Check at least one known rule/desc pair
    found = any(
        item["rule"] == "c" and item["desc"] == "Lowercase all characters"
        for item in data["rule_explanations"]
    )
    assert found, "Expected rule 'c' with correct description in response"
    # All items should have 'rule' and 'desc' as strings
    for item in data["rule_explanations"]:
        assert isinstance(item["rule"], str)
        assert isinstance(item["desc"], str)

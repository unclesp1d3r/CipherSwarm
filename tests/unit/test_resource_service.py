import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack_resource_file import AttackResourceType
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


@pytest.mark.asyncio
async def test_list_rulelists_service_returns_only_rulelists_and_supports_search(
    db_session: AsyncSession,
) -> None:
    # Create rulelists and wordlists
    rule1 = AttackResourceFileFactory.build(
        file_name="rules1.rule", resource_type=AttackResourceType.RULE_LIST
    )
    rule2 = AttackResourceFileFactory.build(
        file_name="rules2.rule", resource_type=AttackResourceType.RULE_LIST
    )
    word1 = AttackResourceFileFactory.build(
        file_name="words1.txt", resource_type=AttackResourceType.WORD_LIST
    )
    db_session.add_all([rule1, rule2, word1])
    await db_session.commit()

    # Should return only rulelists, sorted by updated_at desc
    from app.core.services.resource_service import list_rulelists_service

    result = await list_rulelists_service(db_session)
    file_names = {r.file_name for r in result}
    assert file_names == {"rules1.rule", "rules2.rule"}
    assert all(r.resource_type == AttackResourceType.RULE_LIST for r in result)

    # Search by file_name
    result = await list_rulelists_service(db_session, q="rules1")
    assert len(result) == 1
    assert result[0].file_name == "rules1.rule"

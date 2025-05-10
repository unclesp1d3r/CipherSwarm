# pyright: reportGeneralTypeIssues=false
import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack import AttackMode, AttackState
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest.fixture(autouse=True)
def set_async_sessions(db_session: AsyncSession) -> None:
    CampaignFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    AttackFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]


@pytest.mark.asyncio
async def test_create_attack_minimal(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(campaign_id=campaign.id)
    assert attack.id is not None
    assert attack.name.startswith("attack-")
    assert attack.state == AttackState.PENDING
    assert attack.hash_type_id == 0
    assert attack.campaign_id == campaign.id


@pytest.mark.asyncio
async def test_attack_enum_enforcement(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    with pytest.raises(sqlalchemy.exc.StatementError):  # noqa: PT012
        await attack_factory.create_async(campaign_id=campaign.id, state="notastate")
        await db_session.commit()
    await db_session.rollback()
    with pytest.raises(sqlalchemy.exc.StatementError):  # noqa: PT012
        await attack_factory.create_async(
            campaign_id=campaign.id, hash_type_id="notahash"
        )
        await db_session.commit()
    await db_session.rollback()
    with pytest.raises(sqlalchemy.exc.StatementError):  # noqa: PT012
        await attack_factory.create_async(
            campaign_id=campaign.id, attack_mode="notamode"
        )
        await db_session.commit()
    await db_session.rollback()


@pytest.mark.asyncio
async def test_attack_update_and_delete(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        campaign_id=campaign.id,
        state=AttackState.PENDING,
        hash_type_id=100,
        attack_mode=AttackMode.MASK,
    )
    attack.description = "Updated description"
    await db_session.commit()
    assert attack.description == "Updated description"
    await db_session.delete(attack)
    await db_session.commit()
    result = await db_session.get(attack.__class__, attack.id)
    assert result is None

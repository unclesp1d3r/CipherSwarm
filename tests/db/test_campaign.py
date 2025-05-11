import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.campaign import CampaignState
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_campaign_state_field(db_session: AsyncSession) -> None:
    CampaignFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    # Default state should be draft
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    assert campaign.state == CampaignState.DRAFT
    # Set state to active
    campaign_active = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id, state=CampaignState.ACTIVE
    )
    assert campaign_active.state == CampaignState.ACTIVE
    # Set state to archived
    campaign_archived = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id, state=CampaignState.ARCHIVED
    )
    assert campaign_archived.state == CampaignState.ARCHIVED

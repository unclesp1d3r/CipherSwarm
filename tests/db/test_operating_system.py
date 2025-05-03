import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.operating_system import OSName
from tests.factories.operating_system_factory import OperatingSystemFactory


@pytest.mark.asyncio
async def test_create_operating_system_minimal(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    operating_system = operating_system_factory.build()
    db_session.add(operating_system)
    await db_session.commit()
    await db_session.refresh(operating_system)
    assert operating_system.id is not None
    assert operating_system.name == OSName.linux
    assert operating_system.cracker_command.startswith("hashcat")


@pytest.mark.asyncio
async def test_operating_system_enum_enforcement(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    os = operating_system_factory.build(name="not_an_os")
    db_session.add(os)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_operating_system_unique_name_constraint(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    os1 = operating_system_factory.build(name=OSName.windows)
    db_session.add(os1)
    await db_session.commit()
    await db_session.refresh(os1)
    os2 = operating_system_factory.build(name=OSName.windows)
    db_session.add(os2)
    with pytest.raises(sqlalchemy.exc.IntegrityError):
        await db_session.commit()
    await db_session.rollback()


@pytest.mark.asyncio
async def test_operating_system_update_and_delete(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    os = operating_system_factory.build(name=OSName.darwin)
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    os.cracker_command = "hashcat -m 22000"
    await db_session.commit()
    await db_session.refresh(os)
    assert os.cracker_command == "hashcat -m 22000"
    await db_session.delete(os)
    await db_session.commit()
    result = await db_session.get(os.__class__, os.id)
    assert result is None

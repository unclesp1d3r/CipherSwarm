import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.operating_system import OSName
from tests.factories.operating_system_factory import OperatingSystemFactory


@pytest.mark.asyncio
async def test_create_operating_system_minimal(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    OperatingSystemFactory.__async_session__ = db_session
    os = await operating_system_factory.create_async(name=OSName.linux)
    assert os.id is not None
    assert os.name == OSName.linux
    assert os.cracker_command.startswith("hashcat")


@pytest.mark.asyncio
async def test_operating_system_enum_enforcement(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    OperatingSystemFactory.__async_session__ = db_session
    with pytest.raises(sqlalchemy.exc.StatementError):
        await operating_system_factory.create_async(name="not_an_os")
    await db_session.commit()


@pytest.mark.asyncio
async def test_operating_system_unique_name_constraint(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    OperatingSystemFactory.__async_session__ = db_session
    await operating_system_factory.create_async(name=OSName.darwin)
    with pytest.raises(sqlalchemy.exc.IntegrityError):
        # Should fail due to unique constraint
        await operating_system_factory.create_async(name=OSName.darwin)


@pytest.mark.asyncio
async def test_operating_system_update_and_delete(
    operating_system_factory: OperatingSystemFactory, db_session: AsyncSession
) -> None:
    OperatingSystemFactory.__async_session__ = db_session
    os = await operating_system_factory.create_async(name=OSName.darwin)
    os.cracker_command = "hashcat -m 22000"
    await db_session.commit()
    assert os.cracker_command == "hashcat -m 22000"
    await db_session.delete(os)
    await db_session.commit()
    result = await db_session.get(os.__class__, os.id)
    assert result is None

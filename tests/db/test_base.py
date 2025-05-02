"""Tests for base model functionality."""

import asyncio
from datetime import datetime

import pytest
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TestModel(Base):
    """Test model for base functionality."""

    __tablename__ = "test_models"

    name: Mapped[str] = mapped_column(String(50))


@pytest.mark.asyncio
async def test_base_model_id(db_session):
    """Test that base model generates UUID primary key."""
    model = TestModel(name="test")
    db_session.add(model)
    await db_session.commit()

    assert model.id is not None
    # Verify UUID format
    assert len(str(model.id)) == 36


@pytest.mark.asyncio
async def test_base_model_timestamps(db_session):
    """Test that base model automatically sets timestamps."""
    model = TestModel(name="test")
    db_session.add(model)
    await db_session.commit()

    assert isinstance(model.created_at, datetime)
    assert isinstance(model.updated_at, datetime)
    assert model.created_at <= model.updated_at


@pytest.mark.asyncio
async def test_base_model_update_timestamp(db_session):
    """Test that updated_at is automatically updated."""
    model = TestModel(name="test")
    db_session.add(model)
    await db_session.commit()

    original_updated_at = model.updated_at

    # Wait a moment to ensure timestamp difference
    await asyncio.sleep(0.1)

    # Refresh the session to avoid stale data
    await db_session.refresh(model)

    model.name = "updated"
    await db_session.commit()

    # Refresh again to get the new timestamp
    await db_session.refresh(model)

    assert model.updated_at > original_updated_at
    assert model.created_at < model.updated_at


@pytest.mark.asyncio
async def test_base_model_repr(db_session):
    """Test the string representation of the model."""
    model = TestModel(name="test")
    db_session.add(model)
    await db_session.commit()

    expected = f"<TestModel(id={model.id})>"
    assert str(model) == expected
    assert repr(model) == expected

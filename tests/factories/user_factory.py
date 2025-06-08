import secrets
from datetime import UTC, datetime

from faker import Faker
from passlib.hash import bcrypt
from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.user import User, UserRole

fake = Faker()


class UserFactory(SQLAlchemyFactory[User]):
    __model__ = User
    __async_session__ = None
    _name_counter = 0
    _email_counter = 0

    @classmethod
    def name(cls) -> str:
        cls._name_counter += 1
        return f"user-{cls.__faker__.uuid4()}-{cls._name_counter}"

    @classmethod
    def email(cls) -> str:
        cls._email_counter += 1
        return f"user{cls._email_counter}-{cls.__faker__.uuid4()}@example.com"

    # Always use a valid bcrypt hash for 'password'
    hashed_password = bcrypt.hash("password")
    is_active = True
    is_verified = True
    role = UserRole.ANALYST
    is_superuser = False
    reset_password_token = Use(lambda: fake.unique.uuid4())

    # Control API key fields - generate realistic keys
    @classmethod
    def api_key_full(cls) -> str:
        # Generate a realistic API key format: cst_<uuid>_<random>
        return f"cst_{cls.__faker__.uuid4()}_{secrets.token_hex(24)}"

    @classmethod
    def api_key_readonly(cls) -> str:
        # Generate a realistic API key format: cst_<uuid>_<random>
        return f"cst_{cls.__faker__.uuid4()}_{secrets.token_hex(24)}"

    api_key_full_created_at = Use(lambda: datetime.now(UTC))
    api_key_readonly_created_at = Use(lambda: datetime.now(UTC))
    # No FKs; pure factory.


# Don't try to override build or create_async methods

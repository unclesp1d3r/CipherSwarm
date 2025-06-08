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

    # Control API key fields - default to None
    api_key_full = None
    api_key_readonly = None
    api_key_full_created_at = None
    api_key_readonly_created_at = None
    # No FKs; pure factory.


# Don't try to override build or create_async methods

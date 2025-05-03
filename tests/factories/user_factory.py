# type: ignore[assignment]

from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.user import User, UserRole


class UserFactory(SQLAlchemyFactory[User]):
    __model__ = User
    email = "user@example.com"
    name = "UserTest"
    role = UserRole.analyst
    is_active = True
    is_superuser = False
    is_verified = True
    hashed_password = (
        "$argon2id$v=19$m=102400,t=2,p=8$saltsaltsalt$hashhashhashhashhashhashhashhash"
    )

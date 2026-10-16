import os
import secrets

from datetime import datetime, timedelta, timezone

import jwt
from jwt.exceptions import InvalidTokenError
from pwdlib import PasswordHash

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from fastapi.security import (
    OAuth2PasswordBearer,
    OAuth2PasswordRequestForm,
)

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import User


JWT_SECRET = os.environ["JWT_SECRET_KEY"]
REGISTRATION_CODE = os.environ["REGISTRATION_CODE"]

if len(JWT_SECRET) < 32:
    raise RuntimeError("JWT_SECRET_KEY is too short")

ALGORITHM = "HS256"
ISSUER = "music-library-api"
AUDIENCE = "music-library-users"
TOKEN_EXPIRE_MINUTES = 30

password_hasher = PasswordHash.recommended()

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="auth/token"
)

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"],
)


class RegisterRequest(BaseModel):
    username: str = Field(
        min_length=3,
        max_length=50,
        pattern=r"^[a-zA-Z0-9_-]+$",
    )
    password: str = Field(
        min_length=12,
        max_length=128,
    )
    registration_code: str


class UserResponse(BaseModel):
    id: int
    username: str

    model_config = ConfigDict(from_attributes=True)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


def create_access_token(user: User) -> str:
    now = datetime.now(timezone.utc)

    payload = {
        "sub": str(user.id),
        "iat": now,
        "exp": now + timedelta(
            minutes=TOKEN_EXPIRE_MINUTES
        ),
        "iss": ISSUER,
        "aud": AUDIENCE,
        "token_type": "access",
    }

    return jwt.encode(
        payload,
        JWT_SECRET,
        algorithm=ALGORITHM,
    )


def require_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    unauthorized = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[ALGORITHM],
            audience=AUDIENCE,
            issuer=ISSUER,
            options={
                "require": [
                    "sub",
                    "exp",
                    "iat",
                    "iss",
                    "aud",
                ]
            },
        )

        user_id = payload.get("sub")

        if (
            not isinstance(user_id, str)
            or not user_id.isdecimal()
            or payload.get("token_type") != "access"
        ):
            raise unauthorized

    except InvalidTokenError:
        raise unauthorized

    user = db.get(User, int(user_id))

    if user is None:
        raise unauthorized

    return user


@router.post(
    "/register",
    response_model=UserResponse,
    status_code=201,
)
def register(
    data: RegisterRequest,
    db: Session = Depends(get_db),
):
    valid_code = secrets.compare_digest(
        data.registration_code.encode("utf-8"),
        REGISTRATION_CODE.encode("utf-8"),
    )

    if not valid_code:
        raise HTTPException(
            status_code=403,
            detail="Invalid registration code",
        )

    existing = db.scalar(
        select(User).where(
            User.username == data.username
        )
    )

    if existing:
        raise HTTPException(
            status_code=409,
            detail="Username already exists",
        )

    user = User(
        username=data.username,
        password_hash=password_hasher.hash(
            data.password
        ),
    )

    db.add(user)

    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Username already exists",
        )

    db.refresh(user)
    return user


@router.post(
    "/token",
    response_model=TokenResponse,
)
def login(
    form: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = db.scalar(
        select(User).where(
            User.username == form.username
        )
    )

    if (
        user is None
        or not password_hasher.verify(
            form.password,
            user.password_hash,
        )
    ):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={
                "WWW-Authenticate": "Bearer"
            },
        )

    return TokenResponse(
        access_token=create_access_token(user)
    )


@router.get(
    "/me",
    response_model=UserResponse,
)
def get_profile(
    user: User = Depends(require_user),
):
    return user

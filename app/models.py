from sqlalchemy import Integer, String, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Song(Base):
    __tablename__ = "songs"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False
    )

    artist: Mapped[str] = mapped_column(
        String(200),
        nullable=False
    )

    duration: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
    )

    username: Mapped[str] = mapped_column(
        String(50),
        unique=True,
        index=True,
        nullable=False,
    )

    password_hash: Mapped[str] = mapped_column(
        String(255),
        nullable=False,
    )

class MusicTask(Base):
    __tablename__ = "music_tasks"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True
    )

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey("users.id"),
        nullable=False
    )

    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False
    )

    artist: Mapped[str] = mapped_column(
        String(200),
        nullable=False
    )

    duration: Mapped[int] = mapped_column(
        Integer,
        nullable=False
    )

    status: Mapped[str] = mapped_column(
        String(20),
        default="queued",
        nullable=False
    )

    song_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey("songs.id"),
        nullable=True
    )

    error: Mapped[str | None] = mapped_column(
        String(500),
        nullable=True
    )
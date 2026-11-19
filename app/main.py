import logging
from uuid import uuid4
from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.models import Song, User, MusicTask
from app.auth import router as auth_router, require_user
from app.queue_service import enqueue_music_task
from fastapi import Header
from app.idempotency import run_idempotent

from app.cache import (
    get_cached_songs,
    save_cached_songs,
    get_cache_stats,
)


class SongCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    artist: str = Field(min_length=1, max_length=200)
    duration: int = Field(gt=0)


class SongResponse(SongCreate):
    id: int

    model_config = ConfigDict(from_attributes=True)


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Music Library API",
    description="REST API for managing songs",
    version="1.0.0",
    lifespan=lifespan
)

app.include_router(auth_router)

@app.get("/")
def home():
    return {
        "message": "Music Library API v2 deployed automatically",
        "deployment": "GitHub Actions",
        "version": "2.0.0"
    }



@app.get("/health")
def health(db: Session = Depends(get_db)):
    db.execute(text("SELECT 1"))
    return {
        "status": "healthy",
        "database": "connected"
    }


@app.get("/songs", response_model=list[SongResponse])
def get_songs(db: Session = Depends(get_db)):

    cached_songs = get_cached_songs()

    if cached_songs is not None:
        return cached_songs

    songs = db.scalars(
        select(Song).order_by(Song.id)
    ).all()

    result = [
        SongResponse.model_validate(song).model_dump()
        for song in songs
    ]

    save_cached_songs(result)

    return result

@app.get("/cache/stats")
def cache_stats():
    return get_cache_stats()


@app.get("/songs/{song_id}", response_model=SongResponse)
def get_song(
    song_id: int,
    db: Session = Depends(get_db)
):
    song = db.get(Song, song_id)

    if not song:
        raise HTTPException(
            status_code=404,
            detail="Song not found"
        )

    return song


@app.post(
    "/songs",
    response_model=SongResponse,
    status_code=201
)
def create_song(
    song: SongCreate,
    db: Session = Depends(get_db),
    _user: User = Depends(require_user),
):

    new_song = Song(**song.model_dump())

    db.add(new_song)
    db.commit()
    db.refresh(new_song)
    invalidate_songs_cache()

    return new_song


@app.delete("/songs/{song_id}")
def delete_song(
    song_id: int,
    db: Session = Depends(get_db),
    _user: User = Depends(require_user),
):

    song = db.get(Song, song_id)

    if not song:
        raise HTTPException(
            status_code=404,
            detail="Song not found"
        )

    db.delete(song)
    db.commit()
    invalidate_songs_cache()

    return {
        "message": "Song deleted successfully"
    }

from app.cache import (
    get_cached_songs,
    save_cached_songs,
    get_cache_stats,
    invalidate_songs_cache,
)

@app.post("/songs/async", status_code=202)
def create_song_async(
    song: SongCreate,
    db: Session = Depends(get_db),
    user: User = Depends(require_user),
    idempotency_key: str | None = Header(
        default=None,
        alias="Idempotency-Key"
    ),
):

    def create_task():
        job_id = str(uuid4())

        task = MusicTask(
            id=job_id,
            user_id=user.id,
            title=song.title,
            artist=song.artist,
            duration=song.duration,
            status="queued"
        )

        db.add(task)
        db.commit()

        try:
            enqueue_music_task(job_id)

        except Exception:
            logging.exception("Failed to send task to Service Bus")

            task.status = "failed"
            task.error = "Service Bus unavailable"
            db.commit()

            raise HTTPException(
                status_code=503,
                detail="Could not send task to queue"
            )

        return {
            "job_id": job_id,
            "status": "queued",
            "status_url": f"/jobs/{job_id}"
        }

    if idempotency_key is None:
        return create_task()

    return run_idempotent(
        user_id=user.id,
        key=idempotency_key,
        payload=song.model_dump(),
        operation=create_task
    )

@app.get("/jobs/{job_id}")
def get_job_status(
    job_id: str,
    db: Session = Depends(get_db),
    user: User = Depends(require_user),
):
    task = db.get(MusicTask, job_id)

    if not task or task.user_id != user.id:
        raise HTTPException(
            status_code=404,
            detail="Task not found"
        )

    return {
        "job_id": task.id,
        "status": task.status,
        "song_id": task.song_id,
        "error": task.error
    }
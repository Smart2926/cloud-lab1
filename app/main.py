from contextlib import asynccontextmanager

from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.database import Base, engine, get_db
from app.models import Song, User
from app.auth import router as auth_router, require_user



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
    return db.scalars(
        select(Song).order_by(Song.id)
    ).all()


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

    return {
        "message": "Song deleted successfully"
    }

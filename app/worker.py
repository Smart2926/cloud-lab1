import json
import logging
import os
import time

from azure.servicebus import ServiceBusClient, ServiceBusReceiveMode
from sqlalchemy import select

from app.database import SessionLocal
from app.models import MusicTask, Song
from app.cache import invalidate_songs_cache


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def process_task(job_id):

    with SessionLocal.begin() as db:
        task = db.execute(
            select(MusicTask)
            .where(MusicTask.id == job_id)
            .with_for_update()
        ).scalar_one_or_none()

        if task is None:
            raise ValueError("Task not found")

        if task.status == "completed":
            logger.info("Task %s already completed", job_id)
            return

        task.status = "processing"

    time.sleep(float(os.getenv("WORKER_DELAY_SECONDS", "2")))


    with SessionLocal.begin() as db:
        task = db.execute(
            select(MusicTask)
            .where(MusicTask.id == job_id)
            .with_for_update()
        ).scalar_one_or_none()

        if task is None:
            raise ValueError("Task not found")

        if task.status == "completed":
            return

        song = Song(
            title=task.title,
            artist=task.artist,
            duration=task.duration
        )

        db.add(song)
        db.flush()

        task.song_id = song.id
        task.status = "completed"
        task.error = None
    invalidate_songs_cache()

    logger.info("Task %s completed", job_id)


def mark_failed(job_id):

    with SessionLocal.begin() as db:
        task = db.get(MusicTask, job_id)

        if task and task.status != "completed":
            task.status = "failed"
            task.error = "Worker processing failed"


def main():

    connection_string = os.environ[
        "SERVICEBUS_WORKER_CONNECTION_STRING"
    ]

    queue_name = os.getenv(
        "SERVICEBUS_QUEUE_NAME",
        "music-tasks"
    )

    logger.info("Music Worker started")

    while True:
        try:
            with ServiceBusClient.from_connection_string(
                connection_string
            ) as client:

                with client.get_queue_receiver(
                    queue_name=queue_name,
                    receive_mode=ServiceBusReceiveMode.PEEK_LOCK
                ) as receiver:

                    while True:
                        messages = receiver.receive_messages(
                            max_message_count=1,
                            max_wait_time=10
                        )

                        for message in messages:
                            job_id = None

                            try:
                                data = json.loads(str(message))
                                job_id = data["job_id"]

                                logger.info(
                                    "Processing task %s",
                                    job_id
                                )

                                process_task(job_id)

                                receiver.complete_message(message)

                            except Exception:
                                logger.exception(
                                    "Message processing failed"
                                )

                                if job_id:
                                    mark_failed(job_id)

                                receiver.abandon_message(message)

        except Exception:
            logger.exception("Service Bus connection error")
            time.sleep(5)


if __name__ == "__main__":
    main()
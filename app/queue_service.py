import atexit
import json
import os
import threading

from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.servicebus.exceptions import ServiceBusError


_client = None
_sender = None
_lock = threading.Lock()


def close_queue_publisher():
    global _client, _sender

    try:
        if _sender is not None:
            _sender.close()
    finally:
        _sender = None

        if _client is not None:
            _client.close()

        _client = None


def connect_queue():
    global _client, _sender

    if _sender is not None:
        return

    connection_string = os.environ[
        "SERVICEBUS_SEND_CONNECTION_STRING"
    ]

    queue_name = os.getenv(
        "SERVICEBUS_QUEUE_NAME",
        "music-tasks"
    )

    client = ServiceBusClient.from_connection_string(
        connection_string
    )

    client.__enter__()

    try:
        sender = client.get_queue_sender(
            queue_name=queue_name
        )

        sender.__enter__()

    except Exception:
        client.close()
        raise

    _client = client
    _sender = sender


def enqueue_music_task(job_id: str):
    with _lock:
        connect_queue()

        message = ServiceBusMessage(
            json.dumps({"job_id": job_id})
        )

        try:
            _sender.send_messages(message)

        except ServiceBusError:
            close_queue_publisher()
            raise


atexit.register(close_queue_publisher)
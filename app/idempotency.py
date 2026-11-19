import hashlib
import json
import logging

import redis
from fastapi import HTTPException

from app.cache import redis_client


IDEMPOTENCY_TTL = 86400


def run_idempotent(user_id, key, payload, operation):
    if not key or not key.strip() or len(key) > 128:
        raise HTTPException(
            status_code=400,
            detail="Invalid Idempotency-Key"
        )

    if redis_client is None:
        raise HTTPException(
            status_code=503,
            detail="Redis is required for idempotency"
        )

    key_hash = hashlib.sha256(
        key.encode("utf-8")
    ).hexdigest()

    payload_hash = hashlib.sha256(
        json.dumps(
            payload,
            sort_keys=True,
            ensure_ascii=False
        ).encode("utf-8")
    ).hexdigest()

    redis_key = f"music:idempotency:{user_id}:{key_hash}"
    lock_key = f"{redis_key}:lock"

    try:
        with redis_client.lock(
            lock_key,
            timeout=120,
            blocking_timeout=20
        ):
            cached = redis_client.get(redis_key)

            if cached is not None:
                saved = json.loads(cached)

                if saved["payload_hash"] != payload_hash:
                    raise HTTPException(
                        status_code=409,
                        detail="Idempotency-Key already used with different data"
                    )

                return saved["response"]

            result = operation()

            redis_client.setex(
                redis_key,
                IDEMPOTENCY_TTL,
                json.dumps({
                    "payload_hash": payload_hash,
                    "response": result
                }, ensure_ascii=False)
            )

            return result

    except HTTPException:
        raise

    except (redis.RedisError, ValueError, KeyError) as error:
        logging.exception("Idempotency error: %s", error)

        raise HTTPException(
            status_code=503,
            detail="Idempotency service unavailable"
        )
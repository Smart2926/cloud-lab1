import json
import logging
import os

import redis


CACHE_ENABLED = os.getenv("CACHE_ENABLED", "false").lower() == "true"
CACHE_TTL = int(os.getenv("CACHE_TTL", "60"))

CACHE_KEY = "music:songs:list"
STATS_KEY = "music:cache:stats"

redis_client = None

if CACHE_ENABLED:
    redis_client = redis.Redis(
        host=os.getenv("REDIS_HOST"),
        port=int(os.getenv("REDIS_PORT", "10000")),
        password=os.getenv("REDIS_PASSWORD"),
        ssl=True,
        decode_responses=True,
        socket_connect_timeout=2,
        socket_timeout=2,
    )


def get_cached_songs():
    if redis_client is None:
        return None

    try:
        cached = redis_client.get(CACHE_KEY)

        if cached is not None:
            redis_client.hincrby(STATS_KEY, "hits", 1)
            return json.loads(cached)

        redis_client.hincrby(STATS_KEY, "misses", 1)

    except (redis.RedisError, ValueError) as error:
        logging.warning("Redis read error: %s", error)

    return None


def save_cached_songs(songs):
    if redis_client is None:
        return

    try:
        redis_client.setex(
            CACHE_KEY,
            CACHE_TTL,
            json.dumps(songs, ensure_ascii=False)
        )

    except redis.RedisError as error:
        logging.warning("Redis write error: %s", error)


def get_cache_stats():
    if redis_client is None:
        return {
            "cache_enabled": CACHE_ENABLED,
            "redis_connected": False,
            "hits": 0,
            "misses": 0,
            "hit_rate_percent": 0,
            "ttl_seconds": CACHE_TTL,
        }

    try:
        redis_client.ping()

        stats = redis_client.hgetall(STATS_KEY)

        hits = int(stats.get("hits", 0))
        misses = int(stats.get("misses", 0))
        total = hits + misses

        hit_rate = (hits / total * 100) if total > 0 else 0

        return {
            "cache_enabled": CACHE_ENABLED,
            "redis_connected": True,
            "hits": hits,
            "misses": misses,
            "hit_rate_percent": round(hit_rate, 2),
            "ttl_seconds": CACHE_TTL,
        }

    except redis.RedisError:
        return {
            "cache_enabled": CACHE_ENABLED,
            "redis_connected": False,
            "error": "Redis unavailable",
        }

def invalidate_songs_cache():
    if redis_client is None:
        return

    try:
        redis_client.delete(CACHE_KEY)
    except redis.RedisError as error:
        logging.warning("Redis invalidation error: %s", error)
import http from "k6/http";
import { check } from "k6";

const BASE_URL = __ENV.K6_BASE_URL || "http://localhost:8000";
const TOKEN = __ENV.K6_TOKEN;

export const options = {
  vus: 10,
  iterations: 100,
};

export default function () {
  const body = JSON.stringify({
    title: `Queue Test ${__VU}-${__ITER}-${Date.now()}`,
    artist: "k6 Queue Test",
    duration: 180,
  });

  const response = http.post(
    `${BASE_URL}/songs/async`,
    body,
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${TOKEN}`,
      },
    }
  );

  check(response, {
    "Async accepted 202": (r) => r.status === 202,
  });
}
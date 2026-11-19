import http from "k6/http";
import { check, sleep } from "k6";

const BASE_URL = (
  __ENV.K6_BASE_URL || "http://localhost:8000"
).replace(/\/$/, "");

const USERS = Number(__ENV.K6_VUS || 20);

export const options = {
  stages:
    __ENV.SMOKE === "1"
      ? [
          { duration: "10s", target: 1 },
        ]
      : [
          { duration: "3m", target: USERS },
          { duration: "5m", target: USERS },
          { duration: "2m", target: 0 },
        ],

  summaryTrendStats: [
    "avg",
    "min",
    "med",
    "p(50)",
    "p(95)",
    "p(99)",
    "max",
  ],
};

export function setup() {
  const username = __ENV.K6_USERNAME;
  const password = __ENV.K6_PASSWORD;

  if (!username || !password) {
    throw new Error("Не задано K6_USERNAME або K6_PASSWORD");
  }

  if (__ENV.K6_REGISTRATION_CODE) {
    const register = http.post(
      `${BASE_URL}/auth/register`,
      JSON.stringify({
        username: username,
        password: password,
        registration_code: __ENV.K6_REGISTRATION_CODE,
      }),
      {
        headers: {
          "Content-Type": "application/json",
        },
        responseCallback: http.expectedStatuses(201, 409),
      }
    );

    if (register.status !== 201 && register.status !== 409) {
      throw new Error(`Помилка реєстрації: ${register.status}`);
    }
  }

  const login = http.post(
    `${BASE_URL}/auth/token`,
    {
      username: username,
      password: password,
    }
  );

  if (login.status !== 200) {
    throw new Error(`Помилка авторизації: ${login.status}`);
  }

  return {
    token: login.json("access_token"),
  };
}

export default function (data) {
  const params = {
    headers: {
      Authorization: `Bearer ${data.token}`,
    },
  };

  const create = http.post(
    `${BASE_URL}/songs`,
    JSON.stringify({
      title: `Test Song ${__VU}-${__ITER}-${Date.now()}`,
      artist: "k6 Test",
      duration: 180,
    }),
    {
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${data.token}`,
      },
    }
  );

  const created = check(create, {
    "Song created": (r) => r.status === 201,
  });

  if (!created) {
    sleep(1);
    return;
  }

  const songId = create.json("id");

  for (let i = 0; i < 3; i++) {
    const response = http.get(`${BASE_URL}/songs`);

    check(response, {
      "Songs list OK": (r) => r.status === 200,
    });
  }

  for (let i = 0; i < 5; i++) {
    const response = http.get(
      `${BASE_URL}/songs/${songId}`,
      {
        tags: {
          name: "GET /songs/{id}",
        },
      }
    );

    check(response, {
      "Single song OK": (r) => r.status === 200,
    });
  }

  const profile = http.get(
    `${BASE_URL}/auth/me`,
    params
  );

  check(profile, {
    "Profile OK": (r) => r.status === 200,
  });

  sleep(1);
}
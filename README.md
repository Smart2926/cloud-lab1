# Music Library API

## Опис застосунку

**Music Library API** — REST API для керування музичною бібліотекою, розроблений на Python із використанням FastAPI та PostgreSQL.

Застосунок дозволяє переглядати, додавати та видаляти пісні. Для захисту операцій запису реалізовано JWT-автентифікацію користувачів.

Для розгортання використано Docker, Terraform і Microsoft Azure. Автоматичне оновлення API налаштовано через GitHub Actions.

У лабораторній роботі №2 додано автоматичне масштабування, моніторинг, кешування Redis, асинхронну обробку через Azure Service Bus, ідемпотентність запитів і масштабування за розкладом.

## Публічна адреса

- **API:** http://20.100.173.25/
- **Swagger UI:** http://20.100.173.25/docs
- **OpenAPI:** http://20.100.173.25/openapi.json
- **Health Check:** http://20.100.173.25/health
- **Статистика кешу:** http://20.100.173.25/cache/stats

## Основні можливості

- Перегляд списку пісень та інформації про окрему пісню.
- Створення і видалення пісень із JWT-автентифікацією.
- Асинхронне створення пісень через чергу повідомлень.
- Перевірка стану асинхронного завдання.
- Кешування списку пісень у Redis.
- Захист від повторного створення пісень за допомогою `Idempotency-Key`.
- Автоматичне масштабування API та контейнера-обробника.
- Моніторинг метрик і сповіщення про проблеми.

## Структура проєкту

```text
cloud-lab1/
├── app/
│   ├── main.py             # REST API та маршрути
│   ├── auth.py             # JWT-автентифікація
│   ├── database.py         # Підключення PostgreSQL
│   ├── models.py           # Моделі бази даних
│   ├── cache.py            # Робота з Redis-кешем
│   ├── queue_service.py    # Надсилання повідомлень у Service Bus
│   ├── worker.py           # Асинхронний обробник
│   └── idempotency.py      # Захист від повторних запитів
├── loadtest/
│   ├── loadtest.js         # Тест навантаження API
│   └── queue.js            # Тест асинхронних запитів
├── docs/
│   ├── CACHE.md            # Результати кешування
│   ├── QUEUE.md            # Опис черги повідомлень
│   └── IDEMPOTENCY.md      # Опис ідемпотентності
├── terraform/
│   ├── main.tf             # Основні налаштування Azure
│   ├── registry.tf         # Container Registry
│   ├── postgresql.tf       # PostgreSQL
│   ├── network.tf          # Віртуальна мережа
│   ├── security.tf         # Мережева безпека
│   ├── container_apps.tf   # API та масштабування за розкладом
│   ├── worker.tf           # Контейнер-обробник
│   ├── load_balancer.tf    # Application Gateway
│   ├── github_actions.tf   # OIDC та права доступу
│   ├── monitoring.tf       # Моніторинг та алерти
│   └── redis.tf               # Налаштування Redis та Service Bus
├── .github/workflows/
│   └── deploy.yml          # Автоматичний деплой API
├── Dockerfile
├── compose.yaml
├── requirements.txt
└── README.md
```

## GitHub

https://github.com/Smart2926/cloud-lab1
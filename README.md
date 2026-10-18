# Music Library API

## Опис застосунку

**Music Library API** — REST API для керування музичною бібліотекою, розроблений на Python із використанням FastAPI та PostgreSQL.

Застосунок дозволяє переглядати, додавати та видаляти пісні. Реалізовано JWT-автентифікацію користувачів.

Для розгортання використано Docker, Terraform і Microsoft Azure. Автоматичне оновлення застосунку виконується через GitHub Actions.

## Публічна адреса

- **API:** http://74.248.150.19/
- **Swagger UI:** http://74.248.150.19/docs
- **OpenAPI:** http://74.248.150.19/openapi.json
- **Health Check:** http://74.248.150.19/health

## Структура проєкту

```text
cloud-lab1/
├── app/
│   ├── main.py             # REST API
│   ├── auth.py             # JWT-автентифікація
│   ├── database.py         # Підключення PostgreSQL
│   └── models.py           # Моделі бази даних
├── terraform/
│   ├── main.tf             # Налаштування Azure
│   ├── registry.tf         # Container Registry
│   ├── postgresql.tf       # PostgreSQL
│   ├── network.tf          # Віртуальна мережа
│   ├── security.tf         # Мережева безпека
│   ├── container_apps.tf   # Контейнерний застосунок
│   ├── load_balancer.tf    # Application Gateway
│   ├── github_actions.tf   # OIDC та права доступу
│   └── monitoring.tf       # Моніторинг та алерти
├── .github/workflows/
│   └── deploy.yml          # Автоматичний деплой
├── Dockerfile
├── compose.yaml
├── requirements.txt
└── README.md
```

## GitHub

https://github.com/Smart2926/cloud-lab1
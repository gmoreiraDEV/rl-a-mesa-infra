# À MESA — Infra

Infraestrutura isolada da aplicação:

- PostgreSQL 16 com schema por bounded context;
- Kafka 4 em KRaft;
- Redis 7;
- Keycloak 26;
- provisionamento futuro de observabilidade e Railway.

```bash
docker compose up -d
```

O Compose local usa somente valores fictícios. Produção exige banco, realms, buckets,
credenciais, webhooks e domínios exclusivos da Rebeca Lima.


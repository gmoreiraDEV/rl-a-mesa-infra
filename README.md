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

Procedimentos de backup, restauração, retenção e incidentes estão em `OPERATIONS.md`.
O serviço one-shot `kafka-init` cria explicitamente tópicos versionados e respectivas DLQs;
a criação automática permanece desabilitada.

Os executáveis `scripts/staging-smoke.sh` e `scripts/restore-drill.sh` validam, respectivamente,
uma homologação já publicada e a restauração em banco descartável. Ambos possuem guardas que
recusam alvo de produção; parâmetros e evidências exigidas estão em `OPERATIONS.md`.

`config/r2-cors.example.json` é a base restritiva para upload assinado pelo backoffice. Troque
a origem fictícia pelo domínio exato de cada ambiente antes de aplicar ao bucket privado.

## Railway

O serviço `event-bus` usa este repositório como origem de deploy por push. O `Dockerfile` da
raiz preserva o Kafka upstream e inicia como root porque volumes Railway
novos são montados sem permissão de escrita para o UID 1000 da imagem oficial. O broker
permanece somente na rede privada e persiste KRaft em `/var/lib/kafka/data`.

Cada deployment acionado pelo GitHub deve carregar o `railway.json` da raiz, garantindo o
Dockerfile explícito e impedindo que o serviço seja detectado incorretamente pelo Railpack.

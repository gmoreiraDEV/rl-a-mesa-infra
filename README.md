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
permanece somente na rede privada e persiste KRaft em `/var/lib/kafka/data/kraft`; o
subdiretório evita que entradas do filesystem na raiz do volume sejam lidas como partições.

Cada deployment acionado pelo GitHub deve carregar o `railway.json` da raiz, garantindo o
Dockerfile explícito e impedindo que o serviço seja detectado incorretamente pelo Railpack.

`scripts/provision-keycloak.sh` cria ou atualiza realms, roles, clientes OIDC, audience mapper
e service account sem gravar segredos. O script exige URLs e credenciais via ambiente.

## Tema do Keycloak

O tema `keycloak/themes/a-mesa` personaliza as telas de autenticação e herda do tema
`keycloak.v2`, mantendo os fluxos nativos do Keycloak 26. O Compose monta o diretório em modo
somente leitura. O provisionamento aplica o tema aos realms `a-mesa` e `a-mesa-admin`, ativa a
internacionalização e define português do Brasil (`pt-BR`) como único idioma disponível.

As mensagens cobrem login, recuperação e atualização de senha, confirmação de e-mail, perfil,
OTP, expiração de página e erros. Mensagens não sobrescritas continuam vindo da tradução
portuguesa incluída no Keycloak.

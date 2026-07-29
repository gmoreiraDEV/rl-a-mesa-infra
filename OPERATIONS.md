# Operações

## Ambientes

Development, staging e production usam projetos, bancos, Redis, Kafka, realms Keycloak,
buckets e credenciais independentes. Somente API Gateway, frontends e webhook financeiro
recebem domínio público.

## Backup

Execute `scripts/backup-postgres.sh` diariamente com `DATABASE_URL` e `BACKUP_DIR`. Transfira
o `.dump` e seu checksum para storage criptografado e versionado fora do projeto Railway.
Retenção inicial: 7 diários, 4 semanais e 12 mensais, sujeita à política LGPD.

Arquivos privados usam versionamento e lifecycle do bucket. Banco e bucket devem compartilhar
um identificador de janela de backup para permitir restauração coerente.

## Restauração

Para o ensaio periódico, crie um banco vazio e descartável cujo nome termine obrigatoriamente
em `_restore_drill`. O script valida o checksum quando houver um arquivo
`backup.dump.sha256`, restaura, aplica as migrações independentes dos 12 bounded contexts e
confere schemas e contagens mínimas:

```bash
ENVIRONMENT=staging \
ALLOW_RESTORE_DRILL=yes \
RESTORE_DATABASE_URL=postgresql://.../amesa_restore_drill \
BACKEND_DIR="/caminho/absoluto/backend" \
./scripts/restore-drill.sh /caminho/absoluto/backup.dump
```

O script não cria nem remove bancos e nunca troca tráfego. A limpeza permanece uma ação
explícita do operador. Registre o hash do backup, origem, horário de início e fim, operador,
resultado das migrações, contagens verificadas e tempo total de recuperação.

Para uma restauração real:

1. crie banco vazio em ambiente isolado;
2. valide checksum;
3. restaure e execute migrações;
4. rode smoke tests e confira registros críticos;
5. obtenha aprovação operacional;
6. somente então altere tráfego ou DNS.

Nunca teste restauração diretamente em produção. Registre operador, data, origem do backup e
resultado do smoke test.

## Smoke de staging

`scripts/staging-smoke.sh` exige `SMOKE_TARGET=staging`, URLs públicas de API, app e
backoffice e tokens temporários do membro e da administradora fictícios. O fluxo é somente
leitura e não inicia checkout. Ele valida catálogo, autenticação, isolamento entre clientes,
biblioteca, projeção de auditoria e bloqueio de indexação administrativa. Veja
`../docs/demo-data.md` para a chamada completa.

## Incidentes

Revogue segredos comprometidos antes do redeploy. Webhooks repetidos permanecem seguros pela
idempotência persistida. Mensagens em DLQ exigem inspeção do erro seguro, correção e replay
controlado com o mesmo `EventEnvelope.id`.

## Tópicos Kafka

Execute `scripts/create-kafka-topics.sh` com `KAFKA_BOOTSTRAP_SERVERS`,
`KAFKA_PARTITIONS` e `KAFKA_REPLICATION_FACTOR` adequados ao ambiente. O script é idempotente
e deve rodar antes dos workers. Produção deve usar replication factor compatível com o cluster;
DLQs exigem análise e replay controlado, nunca consumo automático.

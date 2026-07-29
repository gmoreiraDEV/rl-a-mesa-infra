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

1. crie banco vazio em ambiente isolado;
2. valide checksum;
3. defina `RESTORE_DATABASE_URL` e `ALLOW_RESTORE=yes`;
4. execute `scripts/restore-postgres.sh /caminho/backup.dump`;
5. execute migrações, smoke tests e conferência de contagens;
6. somente então altere tráfego ou DNS.

Nunca teste restauração diretamente em produção. Registre operador, data, origem do backup e
resultado do smoke test.

## Incidentes

Revogue segredos comprometidos antes do redeploy. Webhooks repetidos permanecem seguros pela
idempotência persistida. Mensagens em DLQ exigem inspeção do erro seguro, correção e replay
controlado com o mesmo `EventEnvelope.id`.

## Tópicos Kafka

Execute `scripts/create-kafka-topics.sh` com `KAFKA_BOOTSTRAP_SERVERS`,
`KAFKA_PARTITIONS` e `KAFKA_REPLICATION_FACTOR` adequados ao ambiente. O script é idempotente
e deve rodar antes dos workers. Produção deve usar replication factor compatível com o cluster;
DLQs exigem análise e replay controlado, nunca consumo automático.

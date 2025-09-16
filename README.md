# Sinatra Teachable Reports

Aplicação Sinatra que consulta a API pública da Teachable, armazena os dados relevantes em MongoDB e expõe relatórios sobre cursos publicados em formato JSON e HTML. O objetivo é permitir que consultas repetidas sejam atendidas rapidamente através de cache persistente.

## Visão geral

- `TeachableClient` faz paginação segura na API oficial, com retries e tratamento de limite de requisições.
- `TeachableService` coordena o fluxo: busca cursos publicados, pré-carrega matrículas e usuários e salva tudo em coleções Mongo.
- Repositórios (`CourseRepo`, `EnrollmentRepo`, `UserRepo`) controlam o cache, marcando cada coleção com `updated_at` para respeitar o TTL.
- Existem duas rotas principais: `/api/reports/published_courses` (JSON) e `/reports/published_courses` (HTML renderizado com ERB).

## Pré-requisitos

- Ruby 3.1 ou superior
- Bundler (`gem install bundler`)
- MongoDB 6.x (local ou remoto)
- Docker + Docker Compose (opcional, apenas se quiser usar o ambiente containerizado)

## Configuração de ambiente

1. Instale as dependências Ruby:
   ```bash
   bundle install
   ```
2. Configure as variáveis de ambiente. O projeto usa dotenv, então você pode criar um arquivo `.env` na raiz com o conteúdo abaixo (ajuste conforme suas credenciais):
   ```bash
   MONGO_URL=mongodb://localhost:27017/sinatra_db
   TEACHABLE_API_BASE=https://developers.teachable.com
   TEACHABLE_API_KEY=coloque_sua_chave
   CACHE_TTL_SECONDS=900
   ```
3. Garanta que o MongoDB está em execução e acessível pelo `MONGO_URL` configurado.

### Variáveis suportadas

| Variável             | Descrição                                                                        | Padrão                                              |
| -------------------- | -------------------------------------------------------------------------------- | --------------------------------------------------- |
| `MONGO_URL`          | String de conexão com o MongoDB onde o cache será persistido.                    | `mongodb://localhost:27017/sinatra_db`              |
| `TEACHABLE_API_BASE` | URL base da API da Teachable.                                                    | `https://developers.teachable.com`                  |
| `TEACHABLE_API_KEY`  | Chave de API fornecida pela Teachable. **Obrigatória**.                         | _sem padrão_                                        |
| `CACHE_TTL_SECONDS`  | Tempo (em segundos) para considerar o cache ainda fresco antes de refazer fetch. | `900` (15 minutos)                                  |

## Como executar

### Usando Docker Compose

```bash
docker compose up --build
```

O serviço web ficará disponível em `http://localhost:4567`. As alterações no código são recarregadas automaticamente via `rerun`.

### Execução local

1. Exporte as variáveis de ambiente (ou carregue via `.env`).
2. Suba o MongoDB (`brew services start mongodb-community` ou container próprio).
3. Rode a aplicação:
   ```bash
   bundle exec rackup -p 4567 -o 0.0.0.0
   ```

A página HTML com o relatório estará em `http://localhost:4567/reports/published_courses` e a API JSON em `http://localhost:4567/api/reports/published_courses`.

## Fluxo de cache

- Cursos publicados são sincronizados em lotes e gravados na coleção `courses`. Requisições subsequentes usam o cache até que o TTL configure a invalidação.
- Matrículas de um curso são buscadas sob demanda e salvas em `enrollments`. Um documento meta (`user_id: :_meta`) armazena o carimbo de atualização para controle de expiração.
- Usuários são carregados em lote e guardados na coleção `users`. Cada registro contém o payload original (`raw`) para inspeções futuras.

## Endpoints

| Método | Caminho                               | Descrição                                                                            |
| ------ | ------------------------------------- | ------------------------------------------------------------------------------------ |
| `GET`  | `/api/reports/published_courses`      | Retorna JSON com cursos publicados e alunos ativos (nome e e-mail quando disponível). |
| `GET`  | `/reports/published_courses`          | Renderiza o mesmo relatório em HTML com carregamento incremental no navegador.      |

Exemplo de chamada:
```bash
curl http://localhost:4567/api/reports/published_courses | jq
```

## Testes

Os testes utilizam RSpec e WebMock.

```bash
bundle exec rspec
```

## Estrutura principal

```
app.rb                      # Boot do Sinatra + helpers para acessar o service
routes/reports.rb           # Rotas JSON e HTML de relatório
config/environment.rb       # Conexão MongoDB e criação de índices
lib/utils/teachable_client.rb   # Client HTTP com paginação e retries
lib/service/teachable_service.rb# Orquestra cache e sincronização de dados
lib/repository/*             # Repositórios para courses, enrollments e users
views/courses.erb            # Template do relatório em HTML
```

## Licença

Distribuído sob a licença [MIT](LICENSE).

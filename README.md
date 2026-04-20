# LiteLLM proxy (local + production)

OpenAI-compatible LiteLLM gateway with PostgreSQL persistence, env-driven model configuration, and a production deployment path for a DigitalOcean Droplet. Local mode binds LiteLLM to `127.0.0.1`; production mode puts Caddy in front for automatic HTTPS.

For a full Droplet walkthrough, see [DIGITALOCEAN_DROPLET_DEPLOY.md](/Users/anirbanchoudhury/Documents/Projects/liteLLM_proxy/DIGITALOCEAN_DROPLET_DEPLOY.md).

## Deployment modes

This repo now ships three compose layers:

- `docker-compose.yml` — base services shared by every environment
- `docker-compose.local.yml` — localhost-only access on `127.0.0.1:${LITELLM_PORT}`
- `docker-compose.prod.yml` — Caddy reverse proxy on `80/443`, TLS, no public LiteLLM port

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose v2
- For production: a DNS record pointing your domain to the Droplet public IP

## Files

```text
liteLLM_proxy/
├── config.yaml               # model aliases, provider models, api_base, keys via env
├── docker-compose.yml        # base services
├── docker-compose.local.yml  # localhost-only publishing
├── docker-compose.prod.yml   # Caddy + HTTPS publishing
├── Caddyfile                 # TLS termination + reverse proxy
├── env/compose.defaults.env  # local-safe defaults
├── .env.example              # values you must copy into `.env`
├── scripts/litellm           # local and production control commands
├── Makefile                  # wrappers for the control script
└── README.md
```

## Local mode

1. Copy the env template:

   ```bash
   cp .env.example .env
   ```

2. Fill in at least:

   - `API_KEY_1` (and any additional model credentials you use)
   - `LITELLM_MASTER_KEY`

3. Start locally:

   ```bash
   ./scripts/litellm start
   ```

4. Open `http://127.0.0.1:${LITELLM_PORT:-4000}`.

## Production mode on a DigitalOcean Droplet

### 1. Provision the host

- Create an Ubuntu Droplet
- Open firewall ports `22`, `80`, and `443`
- Point your DNS `A` record at the Droplet public IP
- Install Docker Engine and Compose

### 2. Prepare `.env`

Copy `.env.example` to `.env`, then set these production values:

- `PUBLIC_DOMAIN` — the exact hostname clients will use, for example `llm.example.com`
- `LITELLM_MASTER_KEY` — must start with `sk-`
- `POSTGRES_PASSWORD` — strong random password
- `DATABASE_URL` — must match `POSTGRES_PASSWORD`
- `API_KEY_1` ... `API_KEY_12` and any matching alias/model/api_base values you want active

Do not leave `POSTGRES_PASSWORD=litellm_local_dev` in production.

### 3. Start production mode

```bash
./scripts/litellm start-prod
```

This launches:

- `db` on the internal Docker network
- `litellm` on the internal Docker network only
- `caddy` on public ports `80/443`

Caddy terminates TLS and proxies traffic to LiteLLM. Certificate issuance can take a short time on first boot, and it requires DNS to be correct.
Production startup now refuses to run if `.env` still contains placeholder values like `llm.example.com`, `sk-litellm-change-me`, or the sample Postgres password.

### 4. Verify the deployment

```bash
./scripts/litellm status-prod
./scripts/litellm logs-prod
```

Then test the public endpoint:

```bash
curl "https://YOUR_DOMAIN/v1/chat/completions" \
  -H "Authorization: Bearer sk-litellm-your-virtual-key" \
  -H "Content-Type: application/json" \
  -d '{"model":"kimi-k2.5-cloud-1","messages":[{"role":"user","content":"Hello"}]}'
```

## Cursor setup

After LiteLLM is up:

1. Open `https://YOUR_DOMAIN`
2. Log in with `LITELLM_MASTER_KEY`
3. Create a LiteLLM virtual key in the UI
4. In Cursor, use:
   - Base URL: `https://YOUR_DOMAIN/v1`
   - API key: your LiteLLM virtual key
   - Model: one of your configured aliases such as `kimi-k2.5-cloud-1`

## Control commands

### Local

- `./scripts/litellm start`
- `./scripts/litellm stop`
- `./scripts/litellm restart`
- `./scripts/litellm status`
- `./scripts/litellm logs`
- `./scripts/litellm remove`
- `./scripts/litellm remove-all`

### Production

- `./scripts/litellm start-prod`
- `./scripts/litellm stop-prod`
- `./scripts/litellm restart-prod`
- `./scripts/litellm status-prod`
- `./scripts/litellm logs-prod`
- `./scripts/litellm remove-prod`
- `./scripts/litellm remove-all-prod`

Equivalent `make` targets exist for each command.

## Operational notes

- The base compose file does not expose LiteLLM directly; only the local override or production reverse proxy publishes ports.
- Named Docker volumes keep PostgreSQL data and Caddy certificate state between restarts.
- Docker logs are capped with rotation to reduce disk growth on small Droplets.
- The Caddy container only receives `PUBLIC_DOMAIN`; upstream API keys and DB credentials stay scoped to the services that need them.
- `remove` and `remove-prod` keep volumes.
- `remove-all` and `remove-all-prod` delete persistent data.

## Troubleshooting

| Issue | What to check |
|--------|----------------|
| `status-prod` fails on HTTPS | DNS may still be propagating, or Caddy may still be obtaining the certificate |
| Browser gets certificate errors | `PUBLIC_DOMAIN` must match the real hostname, and DNS must point to the Droplet |
| LiteLLM boot loop | Check `./scripts/litellm logs-prod` for Prisma or config errors |
| `401` from upstream model provider | Check `API_KEY_n`, `MODEL_NAME_n`, and `API_BASE_n` in `.env` |
| UI login fails | `LITELLM_MASTER_KEY` must start with `sk-` and match what you type |
| Local mode unreachable | Check `LITELLM_PORT` and whether another process is already using it |

## Security

- Do not commit `.env`.
- Use a strong production `POSTGRES_PASSWORD`.
- Keep the LiteLLM container off the public internet; expose only Caddy on `80/443`.
- Rotate any API key that has been shared or committed previously.

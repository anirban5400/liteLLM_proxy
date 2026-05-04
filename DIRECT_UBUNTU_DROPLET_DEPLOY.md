# Direct Ubuntu Droplet Deployment

This guide runs the LiteLLM proxy directly on a small DigitalOcean Ubuntu Droplet without Docker.

It installs:

- PostgreSQL on the host
- LiteLLM in a Python virtual environment
- a `litellm` systemd service
- Caddy as the HTTPS reverse proxy
- firewall rules for SSH, HTTP, and HTTPS

## Why this helps on a small Droplet

Docker itself is not usually the whole problem, but on a `$4-$6` Droplet the combination of Docker, PostgreSQL, Caddy, image pulls, container logs, overlay filesystem, and low RAM can make the server feel stuck or slow. Running directly removes container overhead and makes logs simpler:

```bash
journalctl -u litellm -f
journalctl -u caddy -f
```

## Prerequisites

- Ubuntu 22.04 or 24.04 Droplet
- domain or subdomain pointed to the Droplet public IP
- ports `80` and `443` open in DigitalOcean cloud firewall if you use one
- this repo cloned on the Droplet

Create a DNS `A` record before running the installer:

```text
llm.yourdomain.com -> YOUR_DROPLET_IP
```

Example:

```bash
ssh root@YOUR_DROPLET_IP
apt update
apt install -y git
cd /opt
git clone YOUR_REPO_URL liteLLM_proxy
cd /opt/liteLLM_proxy
```

## Prepare `.env`

Create `.env` if it does not exist:

```bash
cp .env.example .env
nano .env
```

Set the domain, LiteLLM admin key, and provider model values:

```env
PUBLIC_DOMAIN=llm.yourdomain.com
LITELLM_MASTER_KEY=sk-your-admin-key

ALIAS_NAME_1=kimi-k2.5-cloud-1
MODEL_NAME_1=ollama_chat/kimi-k2.5:cloud
API_BASE_1=https://ollama.com
API_KEY_1=YOUR_PROVIDER_KEY
```

Do not manually set these for a normal first install:

```env
POSTGRES_PASSWORD=
DATABASE_URL=
```

The installer will create/update them automatically:

```env
POSTGRES_PASSWORD=generated-password
DATABASE_URL=postgresql://litellm:generated-password@127.0.0.1:5432/litellm
```

For direct non-Docker installs, `DATABASE_URL` must use `127.0.0.1`. The Docker hostname `db` only works inside Docker Compose.

Save and exit `nano`:

- `Ctrl+O`, then `Enter`
- `Ctrl+X`

## Run the installer

After `.env` is ready:

```bash
sudo ./scripts/install-direct-ubuntu
```

You can also pass the domain directly if you did not put `PUBLIC_DOMAIN` in `.env`:

```bash
sudo ./scripts/install-direct-ubuntu --domain llm.yourdomain.com
```

Use your real domain. `llm.example.com` is only a placeholder.

The script generates a strong LiteLLM admin key if `LITELLM_MASTER_KEY` is missing or still has the placeholder value. It also generates a strong PostgreSQL password if `POSTGRES_PASSWORD` is missing.

Optional:

```bash
sudo ./scripts/install-direct-ubuntu \
  --domain llm.yourdomain.com \
  --admin-key sk-your-admin-key \
  --db-password 'your-strong-db-password'
```

## After install

Check the generated database values:

```bash
grep -E 'POSTGRES_PASSWORD|DATABASE_URL' .env
```

If you edit `.env` after install, restart LiteLLM:

```bash
systemctl restart litellm
```

To log in to PostgreSQL as the LiteLLM database user:

```bash
set -a
source .env
set +a
psql "$DATABASE_URL"
```

To log in as the PostgreSQL admin user:

```bash
sudo -u postgres psql
```

## Check status

```bash
systemctl status litellm
curl http://127.0.0.1:4000/health/liveliness
curl https://YOUR_DOMAIN/health/liveliness
```

Logs:

```bash
journalctl -u litellm -f
journalctl -u caddy -f
```

## Cursor setup

Open:

```text
https://YOUR_DOMAIN
```

Log in with `LITELLM_MASTER_KEY` from `.env`, create a LiteLLM virtual key, then use:

```text
Base URL: https://YOUR_DOMAIN/v1
API key: your LiteLLM virtual key
Model: kimi-k2.5-cloud-1
```

## Updating

After pulling repo changes:

```bash
cd /opt/liteLLM_proxy
git pull
systemctl restart litellm
```

If you want to update the LiteLLM Python package:

```bash
.venv/bin/pip install --upgrade "litellm[proxy]"
systemctl restart litellm
```

## Files created on the Droplet

- `/etc/systemd/system/litellm.service`
- `/etc/caddy/Caddyfile`
- `.venv/`
- `.env`

The database lives in the normal PostgreSQL data directory managed by Ubuntu packages.

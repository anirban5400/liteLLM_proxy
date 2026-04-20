# DigitalOcean Droplet Deployment Guide

This guide shows how to run this LiteLLM proxy project on a DigitalOcean Droplet.

It covers two deployment modes:

- `Production with a domain` — recommended, uses HTTPS via Caddy
- `Temporary without a domain` — for testing only, uses plain HTTP on the Droplet IP

## 1. Create the Droplet

1. In DigitalOcean, create a Droplet.
2. Choose Ubuntu 24.04 LTS or Ubuntu 22.04 LTS.
3. Pick a plan with at least:
   - `1 vCPU`
   - `2 GB RAM`
   - `25 GB disk`
4. Add your SSH key during creation.
5. Note the public IP address after the Droplet is ready.

## 2. SSH into the server

From your local machine:

```bash
ssh root@YOUR_DROPLET_IP
```

If you use a non-root user:

```bash
ssh YOUR_USER@YOUR_DROPLET_IP
```

## 3. Install Docker and Compose

Run these commands on the Droplet:

```bash
apt update
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
docker --version
docker compose version
```

## 4. Configure the firewall

If you use `ufw`, allow the required ports.

For production with a domain:

```bash
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

For temporary no-domain testing:

```bash
ufw allow OpenSSH
ufw allow 4000/tcp
ufw enable
ufw status
```

## 5. Copy the project to the Droplet

Option A: clone from Git if the repo is hosted remotely.

```bash
git clone YOUR_REPO_URL
cd liteLLM_proxy
```

Option B: copy the local project from your machine.

From your local machine:

```bash
scp -r /Users/anirbanchoudhury/Documents/Projects/liteLLM_proxy root@YOUR_DROPLET_IP:/root/
```

Then on the Droplet:

```bash
cd /root/liteLLM_proxy
```

## 6. Create the environment file

On the Droplet:

```bash
cp .env.example .env
```

Then edit it:

```bash
nano .env
```

At minimum, set:	

- `LITELLM_MASTER_KEY`
- `API_KEY_1`

If you use more models, also set the matching:

- `ALIAS_NAME_2`, `MODEL_NAME_2`, `API_BASE_2`, `API_KEY_2`
- `ALIAS_NAME_3`, `MODEL_NAME_3`, `API_BASE_3`, `API_KEY_3`
- and so on

## 7. Choose a deployment mode

## 7A. Production with a domain

Use this if you have a real domain and want Cursor to connect over HTTPS.

### DNS setup

Create an `A` record for your domain or subdomain pointing to the Droplet IP.

Example:

- `llm.example.com -> YOUR_DROPLET_IP`

### Required `.env` values

In `.env`, set these values:

```env
PUBLIC_DOMAIN=llm.example.com
POSTGRES_PASSWORD=use-a-long-random-password
DATABASE_URL=postgresql://litellm:use-a-long-random-password@db:5432/litellm
LITELLM_MASTER_KEY=sk-litellm-your-admin-key

ALIAS_NAME_1=kimi-k2.5-cloud-1
MODEL_NAME_1=ollama/kimi-k2.5:cloud
API_BASE_1=https://ollama.com
API_KEY_1=YOUR_PROVIDER_KEY
```

Important:

- `LITELLM_MASTER_KEY` must start with `sk-`
- `POSTGRES_PASSWORD` and `DATABASE_URL` must match
- `PUBLIC_DOMAIN` must exactly match the hostname you will open in the browser

### Start the production stack

Run:

```bash
./scripts/litellm start-prod
```

### Check the deployment

Run:

```bash
./scripts/litellm status-prod
./scripts/litellm logs-prod
```

Open in the browser:

```text
https://YOUR_DOMAIN
```

Notes:

- Caddy will automatically try to obtain a TLS certificate
- the first start may take a little time
- DNS must already point to the Droplet for HTTPS to succeed

## 7B. Temporary deployment without a domain

Use this only for short-term testing. It exposes plain HTTP on the Droplet IP.

In `.env`, set:

```env
LITELLM_BIND_ADDRESS=0.0.0.0
LITELLM_PORT=4000
LITELLM_MASTER_KEY=sk-litellm-your-admin-key

ALIAS_NAME_1=kimi-k2.5-cloud-1
MODEL_NAME_1=ollama/kimi-k2.5:cloud
API_BASE_1=https://ollama.com
API_KEY_1=YOUR_PROVIDER_KEY
```

Then start:

```bash
./scripts/litellm start
```

Check:

```bash
./scripts/litellm status
./scripts/litellm logs
```

Open:

```text
http://YOUR_DROPLET_IP:4000
```

Important:

- this mode does not use HTTPS
- do not treat it as a long-term public deployment

## 8. Create a LiteLLM virtual key

After the app is up:

1. Open the LiteLLM UI
2. Log in with `LITELLM_MASTER_KEY`
3. Create a virtual key
4. Limit it to the model alias you want if needed

## 9. Connect Cursor

### If using a domain

Use:

- Base URL: `https://YOUR_DOMAIN/v1`
- API key: `YOUR_LITELLM_VIRTUAL_KEY`
- Model: `kimi-k2.5-cloud-1`

### If using only the Droplet IP

Use:

- Base URL: `http://YOUR_DROPLET_IP:4000/v1`
- API key: `YOUR_LITELLM_VIRTUAL_KEY`
- Model: `kimi-k2.5-cloud-1`

If Cursor refuses or behaves inconsistently with plain HTTP, switch to a real domain and use HTTPS.

## 10. Useful commands

Local/IP mode:

```bash
./scripts/litellm start
./scripts/litellm stop
./scripts/litellm restart
./scripts/litellm status
./scripts/litellm logs
```

Production/domain mode:

```bash
./scripts/litellm start-prod
./scripts/litellm stop-prod
./scripts/litellm restart-prod
./scripts/litellm status-prod
./scripts/litellm logs-prod
```

## 11. Updating after a code change

If you update files on the Droplet:

```bash
cd /root/liteLLM_proxy
./scripts/litellm restart
```

Or for production:

```bash
cd /root/liteLLM_proxy
./scripts/litellm restart-prod
```

If you pulled a newer LiteLLM image version, run:

```bash
docker compose pull
```

Then restart the relevant mode.

## 12. Troubleshooting

### App does not start

Check:

```bash
./scripts/litellm logs
```

or:

```bash
./scripts/litellm logs-prod
```

### Production HTTPS does not work

Check:

- DNS is pointing to the Droplet IP
- ports `80` and `443` are open
- `PUBLIC_DOMAIN` is correct
- Caddy logs show successful certificate issuance

### Login fails

Check:

- `LITELLM_MASTER_KEY` starts with `sk-`
- the same value is used in `.env`

### Upstream model returns `401`

Check:

- `API_KEY_1` is valid
- `API_BASE_1` is correct
- `MODEL_NAME_1` is correct

### Database issues

Check:

- `DATABASE_URL` matches `POSTGRES_PASSWORD`
- the `db` container is running

## 13. Recommended first production test

After deployment, test the API directly:

```bash
curl "https://YOUR_DOMAIN/v1/chat/completions" \
  -H "Authorization: Bearer YOUR_LITELLM_VIRTUAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"kimi-k2.5-cloud-1","messages":[{"role":"user","content":"Hello"}]}'
```

If you are in temporary no-domain mode:

```bash
curl "http://YOUR_DROPLET_IP:4000/v1/chat/completions" \
  -H "Authorization: Bearer YOUR_LITELLM_VIRTUAL_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"kimi-k2.5-cloud-1","messages":[{"role":"user","content":"Hello"}]}'
```

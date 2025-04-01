# 🐳 Student Deployment Starter Repo

How to use

```yml
name: Deploy

on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Deploy with Infra
        uses: codeworksacademy/infra@main
        with:
          host: ${{ secrets.HOST }}
          ssh_key: ${{ secrets.SSH_KEY }}
          ghcr_pat: ${{ secrets.GHCR_PAT }}
          env_secrets: '{"ENV_APPNAME": ".env.appname"}'
```


---

## 🚀 How It Works

- Push any of your apps to GHCR (GitHub Container Registry). Use this [action](https://github.com/codeworks-templates/ghcr_trigger)
- Update the `docker-compose.yml` to include your application as a service.
   - Each service can have a matching `.env.<service>` file for environment variables.
- A GitHub Action pushes the compose and env files to an EC2 instance.
- Ansible provisions the EC2 (if needed) and runs Docker Compose.
- Caddy auto-generates HTTPS routes based on service annotations.

---

## 🧾 File Overview

- `.github/workflows/deploy.yml`: Triggered GitHub Action to deploy.
- `docker-compose.yml`: Defines services, domains, mount paths, and metadata.
- `ansible/playbook.yml`: Ansible provisioning and deployment tasks Installs and starts necessary services.
- `ansible/templates/Caddyfile.j2`: Jinja2 template to generate the Caddyfile.

---

## 🔐 Secrets You’ll Need (GitHub Settings)

- `GHCR_PAT`: PAT with `read:packages`
- `HOST`: Public IP or hostname of instance
- `SSH_KEY`: Private SSH key to access the instance
- `ENV_<SERVICE>` (e.g. `ENV_API`, `ENV_FRONTEND`): Line-separated secrets

These ENV_* secrets are used in the GitHub Action to generate .env.* files before uploading them to the EC2 instance. This allows you to keep sensitive information out of the repository while still deploying it securely. You will need to set these secrets in your GitHub repository settings under "Secrets and variables" to ensure the deployment process works correctly. ***Each `ENV_<SERVICE>` that you add will need to be explicily added to the GitHub Action workflow file***


```yml
# Update this section in your `.github/workflows/deploy.yml` 
# include the ENV_* secrets for each service in your docker-compose.yml.
# Make sure your names match the service names in your `docker-compose.yml` file.
- name: Write .env files from secrets
        run: |
          echo "${{ secrets.ENV_API }}" > .env.api
          echo "${{ secrets.ENV_FRONTEND }}" > .env.frontend
```

### 🧪 Example .env.api

```env
API_KEY=secretkeyvalue
CONNECTION_STRING=postgres://user:pass@host/db
```

---

## Docker Compose Labelsdocker

In the `docker-compose.yml`, you can define optional labels for each service to control how Caddy generates the routing configuration. These labels help Caddy understand how to handle incoming requests and map them to the correct service. Supported in the Caddyfile template are the following labels:

- `caddy.domain`: This label specifies the domain(s) for the service. You can use multiple domains separated by commas. Caddy will automatically create HTTPS routes for these domains. For example, `caddy.domain: example.com,www.example.com` will route requests from both domains to this service.
> Note: If you do not specify a domain, Caddy will not create a route for the service, and it will not be accessible via HTTP/HTTPS unless specified in the template or defaults to `localhost`.

- `caddy.type`: This label determines how Caddy will handle the incoming requests for the service. The possible values are:
  - `reverse`: Proxies requests to another service or upstream (default behavior if not specified).
  - `static`: Serves static files from a specified path (requires `caddy.mount_path`).
- `caddy.mount_path`: This label is used with the `caddy.type` label set to `static` to specify a path where static files are served from. This allows you to serve static content directly from a specified directory within your container.


---

## 📦 What Gets Installed on the EC2

- Docker
- Docker Compose
- Caddy (HTTPS & reverse proxy)
- Git, unzip, system tools
- Log rotation via `logrotate`
- Systemd service setup for Docker containers to auto-restart on crash
- Optimized defaults (e.g. limited journald logs, swap disabled)

---

## 🔧 Other Recommendations

- Use private GitHub repos to keep env files secure.
- Use `.gitignore` to avoid committing `.env.*` or sensitive data.
- Ensure your EC2 has a stable domain (Elastic IP or DNS).
- Use GitHub Actions to deploy using `workflow_dispatch`.
- Restart your GitHub Action if changes to services or configs are made.

---

## 🧠 Notes on Compose-Based Setup

You can still use custom labels like `caddy.domain`, `caddy.type`, and `caddy.mount_path` in your service definitions. These will be parsed in the Caddyfile Jinja2 template to map routes and configure static vs reverse proxy behavior.

This approach gives students simple defaults while enabling advanced features like shared networks, volumes, and inter-service communication.



## ⚡ Quick Test

To quickly test your environment replace your `docker-compose.yml` with the following example and push to your repo. This will help you confirm that the deployment process is working correctly and that your GitHub Action is properly configured.

```yaml
version: '3.8'

services:
  frontend:
    image: ghcr.io/jakeoverall/quick-static:latest
    labels:
      caddy.domain: yourdomain.com
      caddy.type: static
      caddy.mount_path: .

  appname:
    image: ghcr.io/jakeoverall/quick:latest
    ports: 
      - "5000:5000"
    env_file:
      - .env.quick 
    labels:
      caddy.domain: yourdomain.com
```

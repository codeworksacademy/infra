# CodeWorks Infra GitHub Action 🐳

This repository contains a standardized structure for deploying student applications to a shared HOST instance. It uses [Docker Compose](https://docs.docker.com/compose/), [Caddy](https://caddyserver.com/), [Ansible](https://docs.ansible.com/), and [GitHub Actions](https://docs.github.com/en/actions) to automate the deployment process.

## Features
- Supports multi-container `docker-compose.yml` deployments
- Automatically extracts static service info from compose
- Handles ENV file injection securely
- Provisions remote host with Ansible
- Uploads code and configuration to HOST

---

## Usage

### Required Secrets
Add the following repository secrets:

| Secret         | Description                                      |
|----------------|--------------------------------------------------|
| `SSH_KEY`      | Private SSH key to access the EC2 host           |
| `HOST`         | IP address or domain of the EC2 host             |
| `GHCR_PAT`     | GitHub token with `read:packages` scope          |
| `ENV_<name>`   | One or more secrets representing your ENV files  |

### Example Workflow
```yaml
name: Deploy to EC2
on:
  workflow_dispatch:

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Prepare .env files                     
        run: |
          printf "%s" "${{ secrets.ENV_APPNAME }}" > .env.appname       # 👈 Add more when needed

      - name: Deploy with Infra
        uses: codeworksacademy/infra@main
        with:
          host: ${{ secrets.HOST }}
          ssh_key: ${{ secrets.SSH_KEY }}
          ghcr_pat: ${{ secrets.GHCR_PAT }}
```

## Docker Compose Requirements

> Must include a valid `docker-compose.yml` in the root of the repo.

```yml
# docker-compose.yml
services:
  frontend:
    container_name: frontend
    image: ghcr.io/username/image:latest
    labels:
      caddy.domain: domain.dev
      caddy.type: static
      caddy.mount_path: /srv/frontend

  appname:
    container_name: appname
    image: ghcr.io/username/image:latest
    ports: 
      - "7045:8080"
    env_file:
      - .env.quick 
    labels:
      caddy.domain: your.domain.dev
```

## 🚀 How It Works

- Push any of your apps to GHCR (GitHub Container Registry). Use this [action](https://github.com/codeworks-templates/ghcr_trigger)
- Update the `docker-compose.yml` to include your application as a service.
   - Each service can have a matching `.env.<service>` file for environment variables.
- A GitHub Action pushes the compose and env files to an HOST instance.
- Ansible provisions the HOST and runs Docker Compose.
- Caddy auto-generates HTTPS routes based on service label annotations.

## Docker Compose Labels

In the `docker-compose.yml`, you can define optional labels for each service to control how Caddy generates the routing configuration. These labels help Caddy understand how to handle incoming requests and map them to the correct service. Supported in the Caddyfile template are the following labels:

- `caddy.domain`: This label specifies the domain(s) for the service. You can use multiple domains separated by commas. Caddy will automatically create HTTPS routes for these domains. For example, `caddy.domain: example.com,www.example.com` will route requests from both domains to this service.
> Note: If you do not specify a domain, Caddy will not create a route for the service, and it will not be accessible via HTTP/HTTPS unless specified in the template or defaults to `localhost`.

- `caddy.type`: This label determines how Caddy will handle the incoming requests for the service. The possible values are:
  - `reverse`: Proxies requests to another service or upstream (*default behavior if not specified*).
  - `static`: Serves static files from a specified path (requires `caddy.mount_path`).
- `caddy.mount_path`: This label is used with the `caddy.type: static` to specify a path where static files are served from. This allows you to serve static content directly from a specified directory within your container.


## 📦 What Gets Installed on the HOST

- Docker
- Docker Compose
- Caddy (HTTPS & reverse proxy)
- Git, unzip, system tools
- Log rotation via `logrotate`
- Systemd service setup for Docker containers to auto-restart on crash
- Optimized defaults (e.g. limited journald logs, swap disabled)

## 🔧 Recommendations

- Use private GitHub repos and images.
- Use `.gitignore` to avoid committing `.env.*` or sensitive data.
- Ensure your HOST has a stable domain (Elastic IP or DNS).

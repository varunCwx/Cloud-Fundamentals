####Cloud Product Dashboard####

A full-stack, cloud-native product dashboard deployed on **Google Cloud Platform** with automated infrastructure using Terraform, a Python/Flask backend, a static HTML (inline JS) , NGINX reverse proxy, and Cloud SQL (PostgreSQL).

---

## Features

- **Product API** with Flask, supporting GET and POST
- **Persistent PostgreSQL database** (Cloud SQL)
- **Static frontend**
- **NGINX reverse proxy**: Handles API and health requests via internal GCP DNS (no IP hardcoding! , took me some time but I managed to do it after some 23-ish tries )
- **Infrastructure-as-code**: Fully automated deploy/redeploy with Terraform (VM, GKE, firewall, DB, IAM, everything)
- **Secure by default**: Backend and database are **never public**, only accessible within GCP VPC
- **Cloud-native**: Scalable, robust, easily portable across projects

---

## Architecture

[BROWSER]
    |
    v
[Frontend Load Balancer (GKE, NGINX, Static HTML)]
    |
    v
[NGINX reverse proxies /api and /health to backend-vm.c.varun-verma-cwx-internal.internal:5000]
    |
    v
[Backend VM: Flask API (Docker)] -- [Cloud SQL (Postgres)]



- Frontend (HTML/JS + NGINX) is served via a public load balancer on GKE.
- NGINX reverse proxies `/api` and `/health` requests to the backend VM, using internal DNS for robustness.
- Backend (Flask) runs in Docker, connects securely to Cloud SQL.
- All infrastructure and networking is managed by Terraform.

---

## Quick Start

### 1. **Clone and Configure**

```sh
git clone https://github.com/varunCwx/Cloud-Fundamentals.git
cd Cloud-Fundamentals
2. Backend
Code: app.py

Requirements: requirements.txt

Local development (optional)
sh
Copy
Edit
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
export DB_USER=...
export DB_PASSWORD=...
export DB_HOST=...
export DB_PORT=5432
export DB_NAME=appdb
python app.py
Docker Build (for GCP VM)
sh
Copy
Edit
docker build -t <your-image-name> .
docker run -p 5000:5000 \
    -e DB_USER=... -e DB_PASSWORD=... -e DB_HOST=... -e DB_PORT=5432 -e DB_NAME=appdb \
    <your-image-name>
3. Frontend
Static HTML/JS: index.html

NGINX config: nginx.conf

Entrypoint: entrypoint.sh

Docker Build (for GKE)
sh
Copy
Edit
docker build -t <your-frontend-image> .
docker run -p 8080:80 <your-frontend-image>
API and health requests (/api/*, /health) are reverse-proxied to the backend VM by internal DNS.

4. Infrastructure
All GCP resources (VM, GKE, Cloud SQL, IAM, firewall, etc.) are managed via main.tf and your other Terraform files.

Deploy on GCP
sh
Copy
Edit
terraform init
terraform apply
Provisioning includes service accounts, networking, internal DNS, and secure-by-default settings.

Outputs include public frontend URL and DB info.

5. Usage
Visit the frontend load balancer IP output by Terraform in your browser.

Add/view products, see health status live.

All API traffic is securely proxied to backend.

File Overview
app.py — Flask API server for product CRUD & health

requirements.txt — Python dependencies

index.html — Static frontend UI (Bootstrap, JS)

nginx.conf — NGINX reverse proxy for API/health to backend VM

entrypoint.sh — Entrypoint script for Docker/NGINX

main.tf — Terraform infrastructure code

Security Notes
No API tokens, DB passwords, or sensitive state are tracked in git (see .gitignore).

Cloud SQL and backend are accessible only within the GCP VPC (never public).

NGINX uses GCP internal DNS for backend proxying, so no IPs are ever hardcoded.

Credits
Created by Varun Verma
CloudWerx Technologies
(c) 2024

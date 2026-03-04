---
title: "I built a zero-cost end-to-end DevOps pipeline (GitHub Actions + Docker + Kubernetes + Docker Hub)"
published: false
description: "How I wired a tiny Flask app from git push → container build → Docker Hub → Kubernetes (locally with kind/minikube). You can copy this for your own portfolio."
tags: devops,cicd,githubactions,docker,kubernetes,dockerhub,terraform
---

I just finished a small but **real** DevOps project and I want to share it in case you’re trying to build your own portfolio.

The idea was simple: **take a tiny app and wire the whole path from `git push` → CI/CD → container registry → Kubernetes**, without paying for any cloud resources. I also wanted something I could point to on freelance platforms and in interviews.

You can grab the code here:

- **GitHub repo**: `https://github.com/rufilboss/devops-e2e-pipeline`
- **Docker Hub image**: `docker.io/asruf/demo-app:latest`

---

## What I built (high level)

Concretely, the project contains:

- **App**: Tiny Flask API (`app/main.py`)
- **Container**: Dockerfile (`app/Dockerfile`)
-, **CI/CD**: GitHub Actions workflow that builds and pushes images to **Docker Hub** (`.github/workflows/ci-cd.yaml`)
- **Kubernetes**: `Deployment` + `Service` (`k8s/*.yaml`)
- **Terraform (optional)**: creates the Kubernetes namespace (`terraform/*.tf`)

Everything here runs **for free** on a local cluster (kind or minikube) and a free Docker Hub + GitHub account.

---

## Prerequisites I used

To follow exactly what I did, you’ll want:

- Git + GitHub repo
- Docker
- `kubectl`
- One local Kubernetes option:
  - **kind** (what I used), or
  - **minikube**
- Terraform (optional, only for the IaC part)
- A **Docker Hub** account (I used `asruf`)

---

## Project layout

This is the layout of the repo:

```text
devops-e2e-pipeline/
├── app
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
├── k8s
│   ├── namespace.yaml
│   └── deployment.yaml
├── terraform
│   ├── main.tf
│   └── k8s.tf
└── .github
    └── workflows
        └── ci-cd.yaml
```

---

## 1) The app I used (simple Flask service)

I deliberately kept the app tiny so the focus is on the **pipeline**, not the code.

It exposes:

- `/` — info about the service (name, version, env, status)
- `/health` — liveness
- `/ready` — readiness

`app/main.py`:

```python
import os
from flask import Flask, jsonify

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENV = os.environ.get("ENV", "dev")

@app.route("/")
def index():
    return jsonify({
        "service": "demo-app",
        "version": VERSION,
        "env": ENV,
        "status": "ok",
    })

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

Dependencies:

`app/requirements.txt`:

```text
flask>=3.0.0
```

The app listens on **port 8080**, which I re-use everywhere (Docker, Kubernetes, port-forward, etc.).

---

## 2) Containerizing it with Docker

My Dockerfile is intentionally straightforward but shows some basic good practices:

- Slim base image
- Non-root user
- Requirements installed in their own layer

`app/Dockerfile`:

```dockerfile
FROM python:3.12-slim AS runtime

WORKDIR /app

RUN adduser --disabled-password --gecos "" appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && pip freeze > requirements.lock

COPY main.py .

USER appuser
EXPOSE 8080

ENV FLASK_APP=main.py
CMD ["python", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080"]
```

### Local sanity check

From the repo root:

```bash
cd devops-e2e-pipeline

docker build -t demo-app:local ./app
docker run --rm -p 8080:8080 --name demo-app-test demo-app:local

# In another terminal:
curl -s http://localhost:8080/health
curl -s http://localhost:8080/
```

That gave me:

- `{"status": "healthy"}` from `/health`
- `{"env":"dev","service":"demo-app","status":"ok","version":"1.0.0"}` from `/`

Once that worked, I moved on to Kubernetes.

---

## 3) Running it on Kubernetes (kind or minikube)

I wanted a “real” deployment with:

- A dedicated namespace
- 2 replicas
- Liveness/readiness probes
- Resource requests/limits

### Starting a local cluster

You can use either tool; I used **kind**, but here are both options.

**minikube:**

```bash
minikube start
```

**kind:**

```bash
kind create cluster --name demo
```

### Making the image visible to the cluster

Kubernetes can’t automatically see `demo-app:local` unless you either:

- build inside the cluster’s Docker daemon (minikube), or
- load the image into kind.

**Option A: minikube**

```bash
eval "$(minikube docker-env)"
docker build -t demo-app:local ./app
```

**Option B: kind** (what I used):

```bash
docker build -t demo-app:local ./app
kind load docker-image demo-app:local --name demo
```

### Kubernetes manifests I used

Namespace:

`k8s/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo-app
  labels:
    app.kubernetes.io/name: demo-app
```

Deployment + Service:

`k8s/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: demo-app
  labels:
    app: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      containers:
        - name: app
          # Local image for kind/minikube:
          # image: demo-app:local
          # Docker Hub image (asruf/demo-app) when using CI/CD:
          image: docker.io/asruf/demo-app:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
              name: http
          env:
            - name: ENV
              value: "production"
            - name: APP_VERSION
              value: "1.0.0"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 3
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: demo-app
  labels:
    app: demo-app
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: demo-app
```

### Applying and testing

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml

kubectl get pods,svc -n demo-app

kubectl port-forward -n demo-app svc/demo-app 8080:80
```

Then in another terminal:

```bash
curl -s http://localhost:8080/health
curl -s http://localhost:8080/ready
curl -s http://localhost:8080/
```

At this point I had the app running as **2 replicas in a local cluster**, fronted by a Service, with working probes.

---

## 4) Pushing to Docker Hub

My Docker Hub username is **`asruf`**. I first pushed manually to make sure everything worked:

```bash
docker tag demo-app:local asruf/demo-app:latest
docker push asruf/demo-app:latest
```

After that, the image was available at:

- `docker.io/asruf/demo-app:latest`

That’s the image the Kubernetes manifest uses by default in this repo.

---

## 5) CI/CD with GitHub Actions → Docker Hub

I wanted the pipeline to:

- Build the image on every push / PR
- Push to Docker Hub on pushes (not PRs)
- Tag images with:
  - the commit SHA
  - `latest` (for the default branch)

The workflow is at `./.github/workflows/ci-cd.yaml`.

### Docker Hub secrets

In my GitHub repo I created 2 **Actions secrets**:

- `DOCKERHUB_USERNAME` — `asruf`
-, `DOCKERHUB_TOKEN` — a Docker Hub access token

You can find these in:

> GitHub repo → Settings → Secrets and variables → Actions

### What the workflow does

High level:

- Check out code
- Set up Buildx
- Log in to Docker Hub with `DOCKERHUB_USERNAME` + `DOCKERHUB_TOKEN`
- Build the Docker image from `./app`
- Tag it with SHA + `latest`
- Push to `docker.io/asruf/demo-app`

So every push to `main` automatically gives me a fresh image on Docker Hub, ready for Kubernetes.

---

## 6) Optional: Terraform for the namespace

I also wanted at least one **Infrastructure as Code** piece in here, so I used Terraform’s Kubernetes provider to create the namespace.

`terraform/main.tf` (provider + versions) and `terraform/k8s.tf` (namespace resource) are already in the repo.

If your `~/.kube/config` points at a running cluster:

```bash
cd terraform

terraform init
terraform plan
terraform apply
```

This is small on purpose, but it’s enough to say **“I manage part of the Kubernetes infrastructure with Terraform”**.

---

## 7) How you can reuse this

If you want to adapt this project for yourself:

- Fork the repo or copy the layout
- Change the **Docker Hub** username and repo name
- Update:
  - `k8s/deployment.yaml` `image:` field
  - GitHub Actions secrets (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`)
- Swap the Flask app for your own service if you like

The nice part is that the pattern stays the same:

> **App → Docker → Docker Hub → Kubernetes → (optional) Terraform**

Once this pipeline is in your portfolio, you can honestly tell people:

> “I’ve built and maintained an end-to-end CI/CD pipeline with GitHub Actions, Docker, Kubernetes, Docker Hub, and Terraform. Here’s the repo and here’s the running app.”

---

## Final thoughts

This project is small, but it touches a lot of the buzzwords you see in job posts and freelance gigs:

- GitHub Actions
- Docker
- Docker Hub
- Kubernetes
- Terraform

If you’re trying to break into DevOps or just want something concrete to show, feel free to **clone my repo, run it locally, and then customize it** to match your own style and stack.


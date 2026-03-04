# End-to-End DevOps Pipeline — Portfolio Project

A **production-style** CI/CD pipeline that matches what clients ask for on Upwork: **GitHub Actions → Docker → Kubernetes**, with optional **Terraform** for infrastructure. Images are pushed to **Docker Hub**. Fully runnable for **free** (no paid cloud required).

## What This Demonstrates

- **CI/CD**: GitHub Actions — build, test, push image on every push/PR
- **Containers**: Multi-stage Dockerfile, small image, health checks
- **Registry**: Docker Hub — simple, widely used container registry
- **Orchestration**: Kubernetes manifests (Deployment, Service, optional Ingress)
- **IaC**: Terraform examples for Kubernetes namespace/resources (or AWS if you add credentials)
- **Local run**: Use minikube/kind + `kubectl` to deploy without cloud

## Quick Start (Local, No Cloud)

```bash
# 1. Clone and enter
cd devops-e2e-pipeline

# 2. Build and run with Docker
docker build -t demo-app ./app
docker run -p 8080:8080 demo-app
# Open http://localhost:8080

# 3. Deploy to Kubernetes (minikube or kind)
kubectl apply -f k8s/
kubectl get pods,svc -n demo-app
kubectl port-forward -n demo-app svc/demo-app 8080:80
# Open http://localhost:8080
```

## Project Layout

```bash
devops-e2e-pipeline/
├── app/                    # Application source
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py
├── k8s/                     # Kubernetes manifests
│   ├── namespace.yaml
│   ├── deployment.yaml
│   └── service.yaml
├── terraform/               # Optional IaC (K8s provider, no cloud)
│   ├── main.tf
│   └── k8s.tf
├── .github/
│   └── workflows/
│       └── ci-cd.yaml       # Build, test, push to Docker Hub
└── README.md
```

## CI/CD Flow (GitHub Actions)

1. **On push/PR**: Checkout → Set up Python → Lint (optional) → Build Docker image
2. **On push to main**: Tag image (SHA + `latest`) → Push to `docker.io/<your-dockerhub-username>/demo-app`
3. **Deploy**: Manual or automated (e.g. `kubectl set image` or Argo CD) using the image from Docker Hub

Requires `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` GitHub secrets for Docker Hub authentication.

## Tech Stack

| Skill        | How It's Used                          |
|-------------|-----------------------------------------|
| GitHub Actions | CI/CD workflow (build, test, push)   |
| Docker      | Containerize app; multi-stage build    |
| Kubernetes  | Deploy manifests (Deployment, Service) |
| Terraform   | Optional: manage K8s namespace/resources|
| Bash/Python | Scripts and app code                    |

## License

[MIT](LICENSE)

# Makefile for K8s GitOps Demo with Prometheus and Grafana
.PHONY: help setup-cluster install-argocd deploy-apps dev-local-release port-forward-all clean

# Variables
CLUSTER_NAME ?= gitops-demo
REGISTRY_PORT ?= 5001
SHA := $(shell git rev-parse --short HEAD)
TIMESTAMP := $(shell date +%Y%m%d-%H%M%S)

# Default target
help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Cluster management
setup-cluster: ## Create kind cluster with local registry
	@echo "🚀 Setting up kind cluster with local registry..."
	cd clusters/kind/scripts && ./kind-with-registry.sh
	@echo "✅ Cluster setup complete!"

delete-cluster: ## Delete the kind cluster
	@echo "🗑️ Deleting kind cluster..."
	kind delete cluster --name $(CLUSTER_NAME)
	docker rm -f kind-registry || true
	@echo "✅ Cluster deleted!"

# ArgoCD installation
install-argocd: ## Install ArgoCD in the cluster
	@echo "📦 Installing ArgoCD..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@echo "⏳ Waiting for ArgoCD to be ready..."
	kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
	@echo "✅ ArgoCD installed!"
	@echo "🔐 ArgoCD admin password:"
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Application deployment
deploy-apps: ## Deploy applications via ArgoCD
	@echo "🚢 Deploying applications..."
	kubectl apply -f gitops/argocd/apps/
	@echo "✅ Applications deployed!"

deploy-monitoring: ## Deploy monitoring stack
	@echo "📊 Deploying monitoring stack..."
	kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@echo "✅ Monitoring stack deployed!"

# Local development
dev-local-build: ## Build image for local registry
	@echo "🔨 Building image for local registry..."
	docker build -t localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA) .
	@echo "✅ Image built: localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA)"

dev-local-push: dev-local-build ## Push image to local registry
	@echo "📤 Pushing to local registry..."
	docker push localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA)
	@echo "✅ Image pushed!"

dev-local-update: ## Update kustomize overlay with new tag
	@echo "📝 Updating kustomization.yaml..."
	yq -i '.images[0].newTag = "dev-$(SHA)"' k8s/podinfo/overlays/dev-local/kustomization.yaml
	@echo "✅ Kustomization updated with tag: dev-$(SHA)"

dev-local-commit: ## Commit the changes to git
	@echo "💾 Committing changes..."
	git add k8s/podinfo/overlays/dev-local/kustomization.yaml
	git commit -m "chore(local): bump image tag to dev-$(SHA)" || echo "No changes to commit"
	@echo "✅ Changes committed!"

dev-local-release: dev-local-push dev-local-update dev-local-commit ## Full local development release
	@echo "🎉 Local release complete! Tag: dev-$(SHA)"

# Port forwarding
port-forward-argocd: ## Port forward ArgoCD server
	@echo "🌐 Port forwarding ArgoCD (http://localhost:8080)..."
	kubectl port-forward svc/argocd-server -n argocd 8080:443

port-forward-grafana: ## Port forward Grafana
	@echo "🌐 Port forwarding Grafana (http://localhost:3000)..."
	kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80

port-forward-prometheus: ## Port forward Prometheus
	@echo "🌐 Port forwarding Prometheus (http://localhost:9090)..."
	kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090

port-forward-podinfo-local: ## Port forward podinfo local
	@echo "🌐 Port forwarding podinfo local (http://localhost:9898)..."
	kubectl port-forward svc/local-podinfo -n demo-local 9898:9898

port-forward-podinfo-ghcr: ## Port forward podinfo ghcr
	@echo "🌐 Port forwarding podinfo ghcr (http://localhost:9899)..."
	kubectl port-forward svc/ghcr-podinfo -n demo-ghcr 9899:9898

port-forward-all: ## Port forward all services (run in background)
	@echo "🌐 Starting all port forwards in background..."
	@make port-forward-argocd &
	@make port-forward-grafana &
	@make port-forward-prometheus &
	@echo "✅ All services available:"
	@echo "  - ArgoCD: http://localhost:8080"
	@echo "  - Grafana: http://localhost:3000 (admin/admin123!@#)"
	@echo "  - Prometheus: http://localhost:9090"

# Status and debugging
status: ## Show cluster and application status
	@echo "📊 Cluster Status:"
	@echo "==================="
	kubectl get nodes
	@echo ""
	@echo "📦 ArgoCD Applications:"
	@echo "======================="
	kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "🎯 Pods Status:"
	@echo "==============="
	kubectl get pods -A | grep -E "(demo-|argocd|monitoring)"

logs-argocd: ## Show ArgoCD server logs
	kubectl logs -n argocd deployment/argocd-server --tail=50

# Cleanup
clean-apps: ## Delete all applications
	@echo "🧹 Cleaning up applications..."
	kubectl delete applications --all -n argocd || true
	kubectl delete namespaces demo-local demo-ghcr monitoring || true

clean: clean-apps delete-cluster ## Full cleanup (delete cluster and apps)
	@echo "✅ Full cleanup complete!"

# Utilities
check-prereqs: ## Check if required tools are installed
	@echo "🔍 Checking prerequisites..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ docker is required but not installed"; exit 1; }
	@command -v kind >/dev/null 2>&1 || { echo "❌ kind is required but not installed"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed"; exit 1; }
	@command -v yq >/dev/null 2>&1 || { echo "❌ yq is required but not installed"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "❌ git is required but not installed"; exit 1; }
	@echo "✅ All prerequisites are installed!"

registry-test: ## Test local registry connectivity
	@echo "🧪 Testing local registry..."
	docker pull busybox:latest
	docker tag busybox:latest localhost:$(REGISTRY_PORT)/test:$(TIMESTAMP)
	docker push localhost:$(REGISTRY_PORT)/test:$(TIMESTAMP)
	@echo "✅ Registry test passed!"

# Quick start
quickstart: check-prereqs setup-cluster install-argocd deploy-apps deploy-monitoring ## Full setup from scratch
	@echo ""
	@echo "🎉 Quick start complete!"
	@echo "========================"
	@echo "Next steps:"
	@echo "1. Run 'make port-forward-all' to access services"
	@echo "2. Run 'make dev-local-release' to deploy local changes"
	@echo "3. Visit http://localhost:8080 for ArgoCD"
	@echo "4. Visit http://localhost:3000 for Grafana (admin/admin123!@#)"
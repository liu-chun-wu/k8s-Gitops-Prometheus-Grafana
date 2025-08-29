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
	@echo "🔍 Verifying ArgoCD installation..."
	@make verify-argocd
	@echo "✅ ArgoCD installed and verified!"
	@echo "🔐 ArgoCD admin password:"
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Ingress setup
install-ingress: ## Install NGINX Ingress Controller for Kind
	@echo "🌐 Installing NGINX Ingress Controller..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo "⏳ Waiting for Ingress Controller to be ready..."
	@sleep 30
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s || true
	@echo "✅ Ingress Controller installed!"

setup-argocd-ingress: ## Setup ArgoCD with Ingress (no port-forward needed)
	@echo "🔧 Configuring ArgoCD for Ingress access..."
	@echo "Setting ArgoCD to insecure mode..."
	kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml || kubectl patch configmap argocd-cmd-params-cm -n argocd --patch-file ingress/argocd/argocd-cmd-params-cm-patch.yaml
	kubectl rollout restart deployment argocd-server -n argocd
	@sleep 10
	@echo "Creating ArgoCD Ingress..."
	kubectl apply -f ingress/argocd/argocd-ingress.yaml
	@echo "✅ ArgoCD Ingress configured!"
	@echo ""
	@echo "📝 Add this line to /etc/hosts:"
	@echo "127.0.0.1 argocd.local"
	@echo ""
	@echo "Then access ArgoCD at: http://argocd.local"

setup-hosts: ## Show /etc/hosts configuration for Ingress
	@echo "📝 Add these lines to /etc/hosts:"
	@echo "127.0.0.1 argocd.local"
	@echo ""
	@echo "Run: sudo sh -c 'echo \"127.0.0.1 argocd.local\" >> /etc/hosts'"

# Application deployment
deploy-apps: ## Deploy all applications (both local and ghcr)
	@echo "🚢 Deploying all applications..."
	kubectl apply -f gitops/argocd/apps/
	@echo "⏳ Waiting for applications to sync..."
	@sleep 15
	@make verify-apps
	@echo "✅ All applications deployed and verified!"

deploy-local: ## Deploy only local podinfo application
	@echo "🚢 Deploying local podinfo application..."
	kubectl apply -f gitops/argocd/apps/podinfo-local.yaml
	@echo "⏳ Waiting for application to sync..."
	@sleep 10
	kubectl get application podinfo-local -n argocd
	@echo "✅ Local podinfo deployed!"

deploy-ghcr: ## Deploy only ghcr podinfo application
	@echo "🚢 Deploying ghcr podinfo application..."
	kubectl apply -f gitops/argocd/apps/podinfo-ghcr.yaml
	@echo "⏳ Waiting for application to sync..."
	@sleep 10
	kubectl get application podinfo-ghcr -n argocd
	@echo "✅ GHCR podinfo deployed!"

delete-local: ## Delete local podinfo application
	@echo "🗑️ Deleting local podinfo application..."
	kubectl delete application podinfo-local -n argocd --ignore-not-found=true
	@echo "✅ Local podinfo deleted!"

delete-ghcr: ## Delete ghcr podinfo application
	@echo "🗑️ Deleting ghcr podinfo application..."
	kubectl delete application podinfo-ghcr -n argocd --ignore-not-found=true
	@echo "✅ GHCR podinfo deleted!"

deploy-monitoring: ## Deploy monitoring stack
	@echo "📊 Deploying monitoring stack..."
	kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@echo "⏳ Waiting for monitoring stack to be ready..."
	@sleep 30
	@make verify-monitoring
	@echo "✅ Monitoring stack deployed and verified!"

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

dev-local-commit: ## Commit and push changes to git
	@echo "💾 Committing changes..."
	@git add k8s/podinfo/overlays/dev-local/kustomization.yaml
	@git commit -m "chore(local): bump image tag to dev-$(SHA)" || echo "No changes to commit"
	@echo "🔄 Syncing with remote..."
	@git pull --rebase origin main || echo "⚠️  Pull failed - manual sync may be needed"
	@git push origin main || echo "⚠️  Push failed - run 'make push' later"
	@echo "✅ Changes committed and synced!"

dev-local-release: dev-local-push dev-local-update dev-local-commit ## Full local development release
	@echo "🎉 Local release complete! Tag: dev-$(SHA)"

# Port forwarding
port-forward-argocd: ## Port forward ArgoCD server
	@echo "🌐 Port forwarding ArgoCD (http://localhost:8081)..."
	kubectl port-forward svc/argocd-server -n argocd 8081:80

port-forward-grafana: ## Port forward Grafana
	@echo "🌐 Port forwarding Grafana (http://localhost:3001)..."
	kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3001:80

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
	@echo "  - ArgoCD: http://localhost:8081"
	@echo "  - Grafana: http://localhost:3001 (admin/prom-operator)"
	@echo "  - Prometheus: http://localhost:9090"

# Verification commands
verify-argocd: ## Verify ArgoCD installation
	@echo "🔍 Verifying ArgoCD installation..."
	@echo "Checking ArgoCD pods..."
	kubectl get pods -n argocd
	@echo "Waiting for all ArgoCD pods to be ready..."
	kubectl wait --for=condition=ready --timeout=300s pods --all -n argocd
	@echo "✅ All ArgoCD pods are ready!"

verify-monitoring: ## Verify monitoring stack deployment
	@echo "🔍 Verifying monitoring stack..."
	@echo "Checking ArgoCD application status..."
	kubectl get application kube-prometheus-stack -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null | grep -q "Synced" || echo "⚠️  Application not synced yet"
	@echo "Checking monitoring namespace..."
	kubectl get ns monitoring 2>/dev/null || echo "⚠️  Monitoring namespace not found"
	@echo "Checking monitoring pods..."
	kubectl get pods -n monitoring 2>/dev/null || echo "⚠️  No monitoring pods found yet"
	@echo "Checking Grafana dashboards ConfigMaps..."
	kubectl get configmap -n monitoring | grep grafana | grep -E "(k8s-views|kubernetes)" || echo "⚠️  Custom dashboards not found yet"
	@echo "✅ Monitoring verification complete!"

redeploy-monitoring: ## Force redeploy monitoring stack with new configuration
	@echo "🔄 Redeploying monitoring stack..."
	kubectl delete application kube-prometheus-stack -n argocd --ignore-not-found=true
	@sleep 10
	kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@echo "✅ Monitoring stack redeployed! Wait for sync to complete."

verify-apps: ## Verify application deployments
	@echo "🔍 Verifying applications..."
	@echo "ArgoCD Applications:"
	kubectl get applications -n argocd
	@echo "Application sync status:"
	kubectl get applications -n argocd -o jsonpath='{range .items[*]}{.metadata.name}: {.status.sync.status}{"\n"}{end}' 2>/dev/null || echo "⚠️  No applications found"
	@echo "✅ Application verification complete!"

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

get-passwords: ## Get actual passwords for all services
	@echo "🔐 Service Credentials:"
	@echo "======================="
	@echo "ArgoCD admin password:"
	kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
	@echo ""
	@echo "Grafana credentials:"
	@echo "Username: admin"
	@echo "Password: $(kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d)"

setup-grafana-dashboards: ## Import modern Kubernetes dashboards to Grafana
	@echo "📊 Setting up modern Grafana dashboards..."
	@echo "Please manually import these recommended dashboards:"
	@echo "1. Kubernetes Cluster Overview (ID: 7249)"
	@echo "2. Kubernetes Pod Overview (ID: 6417)"
	@echo "3. Node Exporter Full (ID: 1860)"
	@echo "4. Prometheus Stats (ID: 2)"
	@echo ""
	@echo "To import:"
	@echo "1. Open Grafana at http://localhost:3001"
	@echo "2. Go to '+' -> Import"
	@echo "3. Enter the Dashboard ID"
	@echo "4. Select 'Prometheus' as data source"
	@echo "✅ This avoids Angular deprecation warnings!"

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

# Git management
git-sync: ## Sync with remote repository (pull with rebase)
	@echo "🔄 Syncing with remote repository..."
	@git pull --rebase origin main || echo "⚠️  Sync failed - may need manual intervention"
	@echo "✅ Sync complete!"

push: ## Safe push with automatic rebase
	@echo "🔄 Pulling latest changes..."
	@git pull --rebase origin main || { echo "❌ Pull failed - resolve conflicts manually"; exit 1; }
	@echo "📤 Pushing to remote..."
	@git push origin main || { echo "❌ Push failed - check your changes"; exit 1; }
	@echo "✅ Push complete!"

# Quick start
quickstart: check-prereqs setup-cluster install-argocd deploy-apps deploy-monitoring ## Full setup from scratch
	@echo ""
	@echo "🎉 Quick start complete!"
	@echo "========================"
	@echo "Next steps:"
	@echo "1. Run 'make port-forward-all' to access services"
	@echo "2. Run 'make dev-local-release' to deploy local changes"
	@echo "3. Visit http://localhost:8081 for ArgoCD"
	@echo "4. Visit http://localhost:3001 for Grafana (admin/prom-operator)"

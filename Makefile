# K8s GitOps Demo - Makefile
.PHONY: help

# Variables
CLUSTER_NAME ?= gitops-demo
REGISTRY_PORT ?= 5001
SHA := $(shell git rev-parse --short HEAD)
MSG ?= "Update"

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

#=============================================================================
# HELP
#=============================================================================
help: ## Show this help message
	@echo "$(CYAN)K8s GitOps Demo - Available Commands$(RESET)"
	@echo "$(CYAN)=====================================$(RESET)"
	@echo ""
	@echo "$(GREEN)Quick Start:$(RESET)"
	@grep -E '^(quickstart|setup|deploy|access|clean):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Development:$(RESET)"
	@grep -E '^(dev|sync|commit|push):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Services:$(RESET)"
	@grep -E '^(forward|ingress|passwords):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Operations:$(RESET)"
	@grep -E '^(status|logs|test):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Usage Examples:$(RESET)"
	@echo "  make quickstart        # 完整環境設置"
	@echo "  make dev              # 本地開發發布"
	@echo "  make commit MSG=\"fix\" # 提交變更"

#=============================================================================
# QUICK START
#=============================================================================
quickstart: ## 🚀 Complete setup with Ingress and monitoring
	@make setup
	@make ingress
	@make deploy
	@echo ""
	@echo "$(GREEN)✅ Quick start complete!$(RESET)"
	@echo "$(CYAN)ArgoCD:$(RESET) http://argocd.local (admin/admin123)"
	@echo "$(CYAN)Grafana:$(RESET) http://localhost:3001 (admin/admin123)"
	@echo "$(CYAN)Prometheus:$(RESET) http://localhost:9090"

setup: ## 📦 Setup cluster and ArgoCD
	@echo "$(CYAN)Setting up Kind cluster...$(RESET)"
	@cd clusters/kind/scripts && ./kind-with-registry.sh
	@echo "$(CYAN)Installing ArgoCD...$(RESET)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
	@echo "$(GREEN)✅ Cluster and ArgoCD ready!$(RESET)"

deploy: ## 🚢 Deploy all applications and monitoring
	@echo "$(CYAN)Deploying applications...$(RESET)"
	@kubectl apply -f gitops/argocd/apps/
	@kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@sleep 10
	@echo "$(GREEN)✅ All applications deployed!$(RESET)"

access: ## 🌐 Show all access URLs and passwords
	@echo "$(CYAN)Service Access Information$(RESET)"
	@echo "$(CYAN)==========================$(RESET)"
	@echo ""
	@echo "$(GREEN)Via Ingress:$(RESET)"
	@echo "  ArgoCD:     http://argocd.local (admin/admin123)"
	@echo "  Grafana:    http://localhost:3001 (admin/admin123)"
	@echo "  Prometheus: http://localhost:9090"
	@echo ""
	@echo "$(GREEN)Via Port-forward:$(RESET)"
	@echo "  Run 'make forward' to start port forwarding"
	@echo ""
	@echo "$(YELLOW)Note: Add '127.0.0.1 argocd.local' to /etc/hosts$(RESET)"

clean: ## 🧹 Delete cluster and all resources
	@echo "$(YELLOW)Cleaning up...$(RESET)"
	@kind delete cluster --name $(CLUSTER_NAME)
	@docker rm -f kind-registry 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup complete!$(RESET)"

#=============================================================================
# DEVELOPMENT
#=============================================================================
dev: ## 🔧 Build, push and deploy local changes
	@echo "$(CYAN)Building and pushing image...$(RESET)"
	@docker build -t localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA) .
	@docker push localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA)
	@echo "$(CYAN)Updating kustomization...$(RESET)"
	@yq -i '.images[0].newTag = "dev-$(SHA)"' k8s/podinfo/overlays/dev-local/kustomization.yaml
	@git add k8s/podinfo/overlays/dev-local/kustomization.yaml
	@git commit -m "chore(local): bump image tag to dev-$(SHA)" || true
	@git push origin main || echo "$(YELLOW)⚠️  Push failed - run 'make push' later$(RESET)"
	@echo "$(GREEN)✅ Local release complete! Tag: dev-$(SHA)$(RESET)"

sync: ## 🔄 Sync with remote repository
	@echo "$(CYAN)Syncing with remote...$(RESET)"
	@git pull --no-rebase origin main || echo "$(YELLOW)⚠️  Sync failed$(RESET)"
	@echo "$(GREEN)✅ Sync complete!$(RESET)"

commit: ## 💾 Commit all changes (usage: make commit MSG="your message")
	@echo "$(CYAN)Committing changes...$(RESET)"
	@git add -A
	@git commit -m "$(MSG)" || echo "No changes to commit"
	@git pull --no-rebase origin main || true
	@git push origin main || echo "$(YELLOW)⚠️  Push failed - run 'make push'$(RESET)"
	@echo "$(GREEN)✅ Changes committed!$(RESET)"

push: ## 📤 Push to remote with auto-merge
	@git pull --no-rebase origin main
	@git push origin main
	@echo "$(GREEN)✅ Push complete!$(RESET)"

#=============================================================================
# SERVICES
#=============================================================================
forward: ## 🔌 Port-forward all services
	@echo "$(CYAN)Starting port forwards...$(RESET)"
	@kubectl port-forward svc/argocd-server -n argocd 8080:80 &
	@kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3001:80 &
	@kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090 &
	@echo "$(GREEN)Services available at:$(RESET)"
	@echo "  ArgoCD:     http://localhost:8080"
	@echo "  Grafana:    http://localhost:3001"
	@echo "  Prometheus: http://localhost:9090"
	@echo "$(YELLOW)Press Ctrl+C to stop port forwarding$(RESET)"

ingress: ## 🌍 Setup Ingress for ArgoCD
	@echo "$(CYAN)Installing NGINX Ingress Controller...$(RESET)"
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@sleep 30
	@echo "$(CYAN)Configuring ArgoCD Ingress...$(RESET)"
	@kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml || true
	@kubectl rollout restart deployment argocd-server -n argocd
	@kubectl apply -f ingress/argocd/argocd-ingress.yaml
	@echo "$(CYAN)Applying fixed password...$(RESET)"
	@kubectl apply -f gitops/argocd/argocd-secret.yaml
	@kubectl rollout restart deployment argocd-server -n argocd
	@echo "$(GREEN)✅ Ingress configured!$(RESET)"
	@echo "$(YELLOW)Add '127.0.0.1 argocd.local' to /etc/hosts$(RESET)"

passwords: ## 🔐 Show all service passwords
	@echo "$(CYAN)Service Credentials$(RESET)"
	@echo "$(CYAN)==================$(RESET)"
	@echo "ArgoCD:  admin / admin123"
	@echo "Grafana: admin / admin123"

#=============================================================================
# OPERATIONS
#=============================================================================
status: ## 📊 Show cluster and application status
	@echo "$(CYAN)Cluster Status:$(RESET)"
	@kubectl get nodes
	@echo ""
	@echo "$(CYAN)ArgoCD Applications:$(RESET)"
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "$(CYAN)Running Pods:$(RESET)"
	@kubectl get pods -A | grep -E "(demo-|argocd|monitoring)" || echo "No pods found"

logs: ## 📜 Show ArgoCD logs
	@kubectl logs -n argocd deployment/argocd-server --tail=50

test: ## 🧪 Test local registry
	@echo "$(CYAN)Testing registry...$(RESET)"
	@docker pull busybox:latest
	@docker tag busybox:latest localhost:$(REGISTRY_PORT)/test:latest
	@docker push localhost:$(REGISTRY_PORT)/test:latest
	@echo "$(GREEN)✅ Registry test passed!$(RESET)"

#=============================================================================
# Individual Components (for advanced users)
#=============================================================================
.PHONY: install-argocd deploy-local deploy-ghcr deploy-monitoring

install-argocd: ## Install only ArgoCD
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

deploy-local: ## Deploy local podinfo app
	@kubectl apply -f gitops/argocd/apps/podinfo-local.yaml

deploy-ghcr: ## Deploy GHCR podinfo app
	@kubectl apply -f gitops/argocd/apps/podinfo-ghcr.yaml

deploy-monitoring: ## Deploy monitoring stack
	@kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
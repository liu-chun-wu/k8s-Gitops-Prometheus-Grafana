# K8s GitOps Demo - Makefile
.PHONY: help quickstart quickstart-local quickstart-ghcr quickstart-both \
        setup setup-local setup-ghcr deploy clean access dev sync \
        commit push update forward ingress passwords fix-ingress \
        status verify-setup logs test setup-ghcr-secret check-ghcr-access \
        install-argocd deploy-local deploy-ghcr deploy-monitoring

# Variables
CLUSTER_NAME ?= gitops-demo
REGISTRY_PORT ?= 5001
DEPLOY_MODE ?= both  # Options: local, ghcr, both
SHA := $(shell git rev-parse --short HEAD)
MSG ?= "Update"

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
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
	@grep -E '^(dev|sync|commit|push|update):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Services:$(RESET)"
	@grep -E '^(forward|ingress|passwords):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Operations:$(RESET)"
	@grep -E '^(status|logs|test):.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Usage Examples:$(RESET)"
	@echo "  make quickstart        # 互動式選擇部署模式"
	@echo "  make quickstart-local  # 本地開發環境"
	@echo "  make quickstart-ghcr   # GHCR 生產環境"
	@echo "  make dev              # 本地開發發布"
	@echo "  make update MSG=\"fix\" # 完整 Git 工作流程"

#=============================================================================
# QUICK START
#=============================================================================
quickstart: ## 🚀 Interactive setup - choose deployment mode
	@echo "$(CYAN)Select deployment mode:$(RESET)"
	@echo "  1) Local (with local registry)"
	@echo "  2) GHCR (GitHub Container Registry)"
	@echo "  3) Both (local + GHCR)"
	@read -p "Enter choice [1-3]: " choice; \
	case $$choice in \
		1) make quickstart-local ;; \
		2) make quickstart-ghcr ;; \
		3) make quickstart-both ;; \
		*) echo "Invalid choice"; exit 1 ;; \
	esac

quickstart-local: ## 🚀 Complete setup for local development
	@make setup-local
	@make ingress
	@make deploy-local
	@make deploy-monitoring
	@echo ""
	@echo "$(GREEN)✅ Local development environment ready!$(RESET)"
	@echo "$(CYAN)ArgoCD:$(RESET) http://argocd.local (admin/admin123)"
	@echo "$(CYAN)Grafana:$(RESET) http://localhost:3001 (admin/admin123)"
	@echo "$(CYAN)Prometheus:$(RESET) http://localhost:9090"
	@echo "$(YELLOW)Local Registry:$(RESET) localhost:$(REGISTRY_PORT)"

quickstart-ghcr: ## 🚀 Complete setup for GHCR deployment
	@make setup-ghcr
	@make ingress
	@make deploy-ghcr
	@make deploy-monitoring
	@echo ""
	@echo "$(GREEN)✅ GHCR deployment environment ready!$(RESET)"
	@echo "$(CYAN)ArgoCD:$(RESET) http://argocd.local (admin/admin123)"
	@echo "$(CYAN)Grafana:$(RESET) http://localhost:3001 (admin/admin123)"
	@echo "$(CYAN)Prometheus:$(RESET) http://localhost:9090"
	@echo "$(YELLOW)Using GHCR:$(RESET) ghcr.io/liu-chun-wu"

quickstart-both: ## 🚀 Complete setup with both local and GHCR
	@make setup-local
	@make ingress
	@make deploy
	@echo ""
	@echo "$(GREEN)✅ Full environment ready (Local + GHCR)!$(RESET)"
	@echo "$(CYAN)ArgoCD:$(RESET) http://argocd.local (admin/admin123)"
	@echo "$(CYAN)Grafana:$(RESET) http://localhost:3001 (admin/admin123)"
	@echo "$(CYAN)Prometheus:$(RESET) http://localhost:9090"

setup: setup-local ## 📦 Setup cluster with local registry and ArgoCD (default)

setup-local: ## 📦 Setup cluster with local registry
	@echo "$(CYAN)Setting up Kind cluster with local registry...$(RESET)"
	@cd clusters/kind/scripts && ./kind-with-registry.sh
	@echo "$(CYAN)Installing ArgoCD...$(RESET)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
	@echo "$(GREEN)✅ Cluster with local registry and ArgoCD ready!$(RESET)"

setup-ghcr: ## 📦 Setup cluster for GHCR only (no local registry)
	@echo "$(CYAN)Setting up Kind cluster without local registry...$(RESET)"
	@cd clusters/kind/scripts && ./kind-with-registry.sh --no-registry
	@echo "$(CYAN)Installing ArgoCD...$(RESET)"
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd
	@kubectl create namespace demo-ghcr --dry-run=client -o yaml | kubectl apply -f -
	@echo "$(GREEN)✅ Cluster for GHCR and ArgoCD ready!$(RESET)"
	@echo ""
	@echo "$(YELLOW)📌 Note: If using private GHCR images, run 'make setup-ghcr-secret'$(RESET)"

deploy: ## 🚢 Deploy all applications and monitoring
	@echo "$(CYAN)Deploying applications...$(RESET)"
	kubectl apply -f gitops/argocd/apps/
	kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@echo "$(CYAN)Waiting for applications to sync...$(RESET)"
	kubectl wait --for=condition=Synced application --all -n argocd --timeout=300s || true
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

update: ## 🚀 Complete git workflow: sync, commit, and push (usage: make update MSG="your message")
	@echo "$(CYAN)Starting complete git workflow...$(RESET)"
	@echo "$(CYAN)Step 1: Syncing with remote...$(RESET)"
	@git pull --no-rebase origin main || echo "$(YELLOW)⚠️  Sync failed - continuing anyway$(RESET)"
	@echo "$(CYAN)Step 2: Adding all changes...$(RESET)"
	@git add -A
	@echo "$(CYAN)Step 3: Committing with message: $(MSG)$(RESET)"
	@git commit -m "$(MSG)" || echo "$(YELLOW)No changes to commit$(RESET)"
	@echo "$(CYAN)Step 4: Final sync before push...$(RESET)"
	@git pull --no-rebase origin main || echo "$(YELLOW)⚠️  Merge may be needed$(RESET)"
	@echo "$(CYAN)Step 5: Pushing to remote...$(RESET)"
	@git push origin main || { echo "$(RED)❌ Push failed - please resolve conflicts$(RESET)"; exit 1; }
	@echo "$(GREEN)✅ Complete workflow successful!$(RESET)"

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
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml || \
		{ echo "$(RED)❌ Failed to install Ingress Controller$(RESET)"; exit 1; }
	@echo "$(CYAN)Patching Ingress Controller to run on control-plane...$(RESET)"
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
		--type='json' -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"ingress-ready": "true"}}]'
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
		--type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"effect": "NoSchedule", "key": "node-role.kubernetes.io/control-plane", "operator": "Equal"}]}]'
	@echo "$(CYAN)Waiting for Ingress Controller to be ready...$(RESET)"
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s || { echo "$(RED)❌ Ingress Controller not ready$(RESET)"; exit 1; }
	@echo "$(CYAN)Configuring ArgoCD...$(RESET)"
	kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml || \
		{ echo "$(RED)❌ Failed to apply ArgoCD config patch$(RESET)"; exit 1; }
	kubectl apply -f ingress/argocd/argocd-ingress.yaml || \
		{ echo "$(RED)❌ Failed to create ArgoCD Ingress$(RESET)"; exit 1; }
	kubectl apply -f gitops/argocd/argocd-secret.yaml
	@echo "$(CYAN)Restarting ArgoCD Server...$(RESET)"
	kubectl rollout restart deployment argocd-server -n argocd
	@echo "$(CYAN)Waiting for ArgoCD to restart...$(RESET)"
	kubectl wait --for=condition=available --timeout=60s deployment/argocd-server -n argocd
	@echo "$(GREEN)✅ Ingress configured!$(RESET)"
	@echo "$(YELLOW)Add '127.0.0.1 argocd.local' to /etc/hosts$(RESET)"

passwords: ## 🔐 Show all service passwords
	@echo "$(CYAN)Service Credentials$(RESET)"
	@echo "$(CYAN)==================$(RESET)"
	@echo "ArgoCD:  admin / admin123"
	@echo "Grafana: admin / admin123"

fix-ingress: ## 🔧 Fix all Ingress and ArgoCD access issues
	@echo "$(CYAN)=== Comprehensive Ingress Fix ===$(RESET)"
	@echo ""
	@echo "$(CYAN)Step 1: Checking current state...$(RESET)"
	@kubectl get pods -n ingress-nginx -o wide 2>/dev/null || echo "Ingress not installed"
	@echo ""
	@echo "$(CYAN)Step 2: Reinstalling Ingress Controller...$(RESET)"
	-kubectl delete namespace ingress-nginx --timeout=30s 2>/dev/null || true
	@sleep 5
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@echo ""
	@echo "$(CYAN)Step 3: Forcing Ingress Controller to control-plane node...$(RESET)"
	@sleep 3
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
		--type='json' -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"ingress-ready": "true"}}]'
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
		--type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"effect": "NoSchedule", "key": "node-role.kubernetes.io/control-plane", "operator": "Equal"}]}]'
	kubectl delete pod -n ingress-nginx -l app.kubernetes.io/component=controller 2>/dev/null || true
	@echo ""
	@echo "$(CYAN)Step 4: Waiting for Ingress Controller...$(RESET)"
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=120s
	@echo ""
	@echo "$(CYAN)Step 5: Fixing ArgoCD configuration...$(RESET)"
	kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' || true
	kubectl delete ingress argocd-server-ingress -n argocd 2>/dev/null || true
	kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml
	kubectl apply -f ingress/argocd/argocd-ingress.yaml
	kubectl apply -f gitops/argocd/argocd-secret.yaml
	kubectl rollout restart deployment argocd-server -n argocd
	kubectl wait --for=condition=available --timeout=60s deployment/argocd-server -n argocd
	@echo ""
	@echo "$(CYAN)Step 6: Verifying setup...$(RESET)"
	@kubectl get pods -n ingress-nginx -o wide | grep controller
	@kubectl get ingress -n argocd
	@echo ""
	@echo "$(CYAN)Step 7: Testing access...$(RESET)"
	@sleep 5
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://argocd.local || echo "Check /etc/hosts"
	@echo ""
	@echo "$(GREEN)✅ Ingress fix complete!$(RESET)"
	@echo "$(YELLOW)Ensure /etc/hosts contains: 127.0.0.1 argocd.local$(RESET)"
	@echo "$(CYAN)Access ArgoCD at: http://argocd.local (admin/admin123)$(RESET)"

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

verify-argocd: ## 🔍 Diagnose ArgoCD access issues
	@echo "$(CYAN)=== Checking ArgoCD pods ===$(RESET)"
	@kubectl get pods -n argocd --no-headers | grep -v Running | grep -v Completed || echo "✅ All ArgoCD pods running"
	@echo ""
	@echo "$(CYAN)=== Checking Ingress Controller ===$(RESET)"
	@kubectl get pods -n ingress-nginx 2>/dev/null | grep Running > /dev/null && echo "✅ Ingress controller running" || echo "❌ Ingress controller not installed"
	@echo ""
	@echo "$(CYAN)=== Checking Ingress resource ===$(RESET)"
	@kubectl get ingress -n argocd 2>/dev/null || echo "❌ No ingress found"
	@echo ""
	@echo "$(CYAN)=== Checking ArgoCD server config ===$(RESET)"
	@kubectl get cm argocd-cmd-params-cm -n argocd -o yaml 2>/dev/null | grep "server.insecure" || echo "❌ Insecure mode not configured"
	@echo ""
	@echo "$(CYAN)=== Testing HTTP access ===$(RESET)"
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://argocd.local 2>/dev/null || echo "❌ ArgoCD not accessible via Ingress"
	@echo ""
	@echo "$(CYAN)=== Direct port-forward test ===$(RESET)"
	@echo "To test direct access, run:"
	@echo "  kubectl port-forward svc/argocd-server -n argocd 8080:80"
	@echo "  Then visit: http://localhost:8080"

verify-setup: ## 🔍 Verify all components are ready
	@echo "$(CYAN)=== Checking Cluster Nodes ===$(RESET)"
	@kubectl get nodes
	@echo ""
	@echo "$(CYAN)=== Checking ArgoCD ===$(RESET)"
	@kubectl get pods -n argocd --no-headers | grep -v Running | grep -v Completed || echo "✅ All ArgoCD pods running"
	@echo ""
	@echo "$(CYAN)=== Checking Ingress Controller ===$(RESET)"
	@kubectl get pods -n ingress-nginx 2>/dev/null | grep Running > /dev/null && echo "✅ Ingress controller running" || echo "❌ Ingress controller not installed"
	@echo ""
	@echo "$(CYAN)=== Checking ArgoCD Ingress ===$(RESET)"
	@kubectl get ingress -n argocd 2>/dev/null | grep argocd > /dev/null && kubectl get ingress -n argocd || echo "❌ No ingress found"
	@echo ""
	@echo "$(CYAN)=== Checking Monitoring Stack ===$(RESET)"
	@kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -v Running | grep -v Completed || echo "✅ All monitoring pods running" || echo "⚠️  Monitoring not installed"
	@echo ""
	@echo "$(CYAN)=== Testing ArgoCD Access ===$(RESET)"
	@curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://argocd.local 2>/dev/null || echo "❌ ArgoCD not accessible (check /etc/hosts)"
	@echo ""
	@echo "$(CYAN)=== Service URLs ===$(RESET)"
	@echo "ArgoCD:     http://argocd.local (admin/admin123)"
	@echo "Grafana:    http://localhost:3001 (admin/admin123)"
	@echo "Prometheus: http://localhost:9090"

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

install-argocd: ## Install only ArgoCD
	@kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

deploy-local: ## Deploy local podinfo app
	@kubectl apply -f gitops/argocd/apps/podinfo-local.yaml

deploy-ghcr: ## Deploy GHCR podinfo app
	@kubectl apply -f gitops/argocd/apps/podinfo-ghcr.yaml

deploy-monitoring: ## Deploy monitoring stack
	kubectl apply -f monitoring/kube-prometheus-stack/application.yaml
	@echo "$(CYAN)Waiting for monitoring stack to sync...$(RESET)"
	kubectl wait --for=condition=Synced application/kube-prometheus-stack -n argocd --timeout=300s || true
	@echo "$(CYAN)Waiting for Prometheus Operator...$(RESET)"
	kubectl wait --for=condition=available deployment/kube-prometheus-stack-operator -n monitoring --timeout=180s || true
	@echo "$(CYAN)Waiting for Grafana...$(RESET)"
	kubectl wait --for=condition=available deployment/kube-prometheus-stack-grafana -n monitoring --timeout=180s || true

#=============================================================================
# GHCR Secret Management
#=============================================================================
setup-ghcr-secret: ## 🔐 Setup GHCR authentication for private images
	@echo "$(CYAN)Setting up GHCR authentication...$(RESET)"
	@echo "$(YELLOW)This is only needed if your GHCR images are private.$(RESET)"
	@echo ""
	@echo "To create a GHCR secret, you need:"
	@echo "  1. GitHub Personal Access Token (PAT) with 'read:packages' scope"
	@echo "  2. Your GitHub username"
	@echo ""
	@echo "Run the following command to create the secret:"
	@echo "$(CYAN)kubectl create secret docker-registry ghcr-secret \\$(RESET)"
	@echo "$(CYAN)  --docker-server=ghcr.io \\$(RESET)"
	@echo "$(CYAN)  --docker-username=YOUR_GITHUB_USERNAME \\$(RESET)"
	@echo "$(CYAN)  --docker-password=YOUR_GITHUB_PAT \\$(RESET)"
	@echo "$(CYAN)  -n demo-ghcr$(RESET)"
	@echo ""
	@echo "Or visit: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry"

check-ghcr-access: ## 🔍 Check if GHCR images are accessible
	@echo "$(CYAN)Checking GHCR image accessibility...$(RESET)"
	@if curl -s https://ghcr.io/v2/liu-chun-wu/k8s-gitops-prometheus-grafana/podinfo/tags/list 2>&1 | grep -q "UNAUTHORIZED"; then \
		echo "$(RED)❌ Images are private - authentication required$(RESET)"; \
		echo "Run 'make setup-ghcr-secret' to configure authentication"; \
	else \
		echo "$(GREEN)✅ Images are public - no authentication needed$(RESET)"; \
	fi
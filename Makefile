# K8s GitOps Demo - Optimized Makefile v3
.PHONY: help quickstart quickstart-local quickstart-ghcr clean \
        cluster-create cluster-delete registry-setup registry-test \
        argocd-install argocd-config ingress-install ingress-config \
        build-local develop-local \
        release-ghcr \
        deploy-app-local deploy-app-ghcr deploy-monitoring \
        verify access logs check-git-status

#=============================================================================
# VARIABLES & SETTINGS
#=============================================================================
CLUSTER_NAME ?= gitops-demo
REGISTRY_PORT ?= 5001
SHA := $(shell git rev-parse --short HEAD)
MSG ?= "Update"
DRY_RUN ?= 0
DETAILED ?= 0
WAIT_TIMEOUT ?= 300s
ARGOCD_PASSWORD ?= admin123
GRAFANA_PASSWORD ?= admin123
GHCR_REGISTRY ?= ghcr.io/liu-chun-wu/k8s-gitops-prometheus-grafana

# Colors for output
CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
RESET := \033[0m

# Unified execute command with dry-run support
define execute_cmd
	@if [ "$(DRY_RUN)" = "1" ]; then \
		echo "$(YELLOW)[DRY_RUN] Would execute: $(1)$(RESET)"; \
	else \
		$(1); \
	fi
endef

# Create namespace if not exists
define create_namespace
	kubectl create namespace $(1) --dry-run=client -o yaml | kubectl apply -f -
endef

#=============================================================================
# HELP DOCUMENTATION
#=============================================================================
help: ## Show all available commands
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║           K8s GitOps Demo - Command Reference             ║$(RESET)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)quickstart$(RESET)         Interactive setup"
	@echo "  $(CYAN)quickstart-local$(RESET)   Complete local development environment"
	@echo "  $(CYAN)quickstart-ghcr$(RESET)    GHCR production environment"
	@echo "  $(CYAN)clean$(RESET)              Delete cluster and all resources"
	@echo ""
	@echo "$(GREEN)💻 Local Development$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)build-local$(RESET)        Build Docker image locally"
	@echo "  $(CYAN)develop-local$(RESET)      Development workflow (build+push+sync ArgoCD)"
	@echo ""
	@echo "$(GREEN)☁️  GHCR Release$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)release-ghcr MSG=\"...\"$(RESET) Release to GHCR (add+commit+sync+push)"
	@echo ""
	@echo "$(GREEN)📦 Deployment$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)deploy-app-local$(RESET)   Deploy local application to cluster"
	@echo "  $(CYAN)deploy-app-ghcr$(RESET)    Deploy GHCR application to cluster"
	@echo "  $(CYAN)deploy-monitoring$(RESET)  Deploy Prometheus & Grafana stack"
	@echo ""
	@echo "$(GREEN)🔧 Infrastructure$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)cluster-create$(RESET)     Create Kind cluster"
	@echo "  $(CYAN)cluster-delete$(RESET)     Delete cluster"
	@echo "  $(CYAN)registry-setup$(RESET)     Setup local Docker registry"
	@echo "  $(CYAN)registry-test$(RESET)      Test registry connectivity"
	@echo "  $(CYAN)argocd-install$(RESET)     Install ArgoCD"
	@echo "  $(CYAN)argocd-config$(RESET)      Configure ArgoCD"
	@echo "  $(CYAN)ingress-install$(RESET)    Install NGINX Ingress Controller"
	@echo "  $(CYAN)ingress-config$(RESET)     Configure Ingress rules"
	@echo ""
	@echo "$(GREEN)📋 Operations$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)verify$(RESET)             Check system status & health"
	@echo "  $(CYAN)access$(RESET)             Show URLs and credentials"
	@echo "  $(CYAN)logs$(RESET)               View ArgoCD server logs"
	@echo ""
	@echo "$(YELLOW)💡 Tips$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  • Preview commands:    $(CYAN)DRY_RUN=1 make quickstart-local$(RESET)"
	@echo "  • Verbose output:      $(CYAN)DETAILED=1 make verify$(RESET)"
	@echo "  • GHCR release:        $(CYAN)make release-ghcr MSG=\"feat: new feature\"$(RESET)"
	@echo "  • Local development:   $(CYAN)make develop-local$(RESET)"
	@echo "  • Initial app setup:   $(CYAN)make deploy-app-local$(RESET) (only needed once)"
	@echo ""

#=============================================================================
# QUICK START COMMANDS
#=============================================================================
quickstart: ## Interactive setup - choose deployment mode
	@echo "$(CYAN)Select deployment mode:$(RESET)"
	@echo "  1) Local (with local registry)"
	@echo "  2) GHCR (GitHub Container Registry)"
	@read -p "Enter choice [1-2]: " choice; \
	case $$choice in \
		1) $(MAKE) quickstart-local DRY_RUN=$(DRY_RUN) ;; \
		2) $(MAKE) quickstart-ghcr DRY_RUN=$(DRY_RUN) ;; \
		*) echo "$(RED)Invalid choice$(RESET)"; exit 1 ;; \
	esac

quickstart-local: ## Complete setup for local development
	@echo "$(CYAN)🚀 Starting local development setup...$(RESET)"
	@$(MAKE) cluster-create DRY_RUN=$(DRY_RUN)
	@$(MAKE) registry-setup DRY_RUN=$(DRY_RUN)
	@$(MAKE) argocd-install DRY_RUN=$(DRY_RUN)
	@$(MAKE) argocd-config DRY_RUN=$(DRY_RUN)
	@$(MAKE) ingress-install DRY_RUN=$(DRY_RUN)
	@$(MAKE) ingress-config DRY_RUN=$(DRY_RUN)
	@$(MAKE) deploy-app-local DRY_RUN=$(DRY_RUN)
	@$(MAKE) deploy-monitoring DRY_RUN=$(DRY_RUN)
	@if [ "$(DRY_RUN)" != "1" ]; then sleep 3; fi
	@$(MAKE) verify
	@echo ""
	@echo "$(GREEN)✅ Local development environment ready!$(RESET)"
	@$(MAKE) access

quickstart-ghcr: ## Complete setup for GHCR deployment
	@echo "$(CYAN)☁️  Starting GHCR deployment setup...$(RESET)"
	@$(MAKE) cluster-create SETUP_REGISTRY=false DRY_RUN=$(DRY_RUN)
	@$(MAKE) argocd-install DRY_RUN=$(DRY_RUN)
	@$(MAKE) argocd-config DRY_RUN=$(DRY_RUN)
	@$(MAKE) ingress-install DRY_RUN=$(DRY_RUN)
	@$(MAKE) ingress-config DRY_RUN=$(DRY_RUN)
	@$(MAKE) deploy-app-ghcr DRY_RUN=$(DRY_RUN)
	@$(MAKE) deploy-monitoring DRY_RUN=$(DRY_RUN)
	@if [ "$(DRY_RUN)" != "1" ]; then sleep 3; fi
	@$(MAKE) verify
	@echo ""
	@echo "$(GREEN)✅ GHCR deployment environment ready!$(RESET)"
	@$(MAKE) access

clean: ## Delete cluster and all resources
	@echo "$(YELLOW)🧹 Cleaning up all resources...$(RESET)"
	$(call execute_cmd, kind delete cluster --name $(CLUSTER_NAME))
	$(call execute_cmd, docker rm -f kind-registry 2>/dev/null || true)
	@echo "$(GREEN)✅ Cleanup complete!$(RESET)"

#=============================================================================
# INFRASTRUCTURE COMPONENTS
#=============================================================================
cluster-create: ## Create Kind cluster
	@echo "$(CYAN)Creating Kind cluster...$(RESET)"
	@if [ "$(DRY_RUN)" = "1" ]; then \
		if [ "$${SETUP_REGISTRY:-true}" = "true" ]; then \
			echo "$(YELLOW)[DRY_RUN] Would execute: cd clusters/kind/scripts && ./kind-with-registry.sh$(RESET)"; \
		else \
			echo "$(YELLOW)[DRY_RUN] Would execute: cd clusters/kind/scripts && ./kind-with-registry.sh --no-registry$(RESET)"; \
		fi; \
	else \
		if [ "$${SETUP_REGISTRY:-true}" = "true" ]; then \
			cd clusters/kind/scripts && ./kind-with-registry.sh; \
		else \
			cd clusters/kind/scripts && ./kind-with-registry.sh --no-registry; \
		fi; \
	fi
	@echo "$(GREEN)✅ Cluster created!$(RESET)"

cluster-delete: ## Delete Kind cluster
	@echo "$(YELLOW)Deleting cluster...$(RESET)"
	$(call execute_cmd, kind delete cluster --name $(CLUSTER_NAME))
	@echo "$(GREEN)✅ Cluster deleted!$(RESET)"

registry-setup: ## Setup local Docker registry
	@echo "$(CYAN)Setting up local registry...$(RESET)"
	@if [ "$(DRY_RUN)" != "1" ] && [ -z "$$(docker ps -q -f name=kind-registry)" ]; then \
		echo "Registry will be set up with cluster creation"; \
	else \
		echo "$(GREEN)✅ Registry already running or in dry-run mode$(RESET)"; \
	fi

registry-test: ## Test local registry connectivity
	@echo "$(CYAN)Testing local registry...$(RESET)"
	$(call execute_cmd, docker pull busybox:latest)
	$(call execute_cmd, docker tag busybox:latest localhost:$(REGISTRY_PORT)/test:latest)
	$(call execute_cmd, docker push localhost:$(REGISTRY_PORT)/test:latest)
	@echo "$(GREEN)✅ Registry test passed!$(RESET)"

#=============================================================================
# ARGOCD COMPONENTS
#=============================================================================
argocd-install: ## Install ArgoCD
	@echo "$(CYAN)Installing ArgoCD...$(RESET)"
	$(call execute_cmd, $(call create_namespace,argocd))
	$(call execute_cmd, kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		kubectl wait --for=condition=available --timeout=$(WAIT_TIMEOUT) deployment/argocd-server -n argocd || \
			{ echo "$(RED)❌ ArgoCD installation failed$(RESET)"; exit 1; }; \
	fi
	@echo "$(GREEN)✅ ArgoCD installed!$(RESET)"

argocd-config: ## Configure ArgoCD settings and secrets
	@echo "$(CYAN)Configuring ArgoCD...$(RESET)"
	$(call execute_cmd, kubectl apply -f gitops/argocd/argocd-secret.yaml)
	$(call execute_cmd, kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}' || true)
	@echo "$(GREEN)✅ ArgoCD configured!$(RESET)"

#=============================================================================
# INGRESS COMPONENTS
#=============================================================================
ingress-install: ## Install NGINX Ingress Controller
	@echo "$(CYAN)Installing NGINX Ingress Controller...$(RESET)"
	$(call execute_cmd, kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		echo "$(CYAN)Waiting for initial deployment...$(RESET)"; \
		sleep 5; \
		kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
			--type='json' -p='[{"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"ingress-ready": "true"}}]' || true; \
		kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
			--type='json' -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": [{"effect": "NoSchedule", "key": "node-role.kubernetes.io/control-plane", "operator": "Equal"}]}]' || true; \
		echo "$(CYAN)Waiting for rollout to complete...$(RESET)"; \
		kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=120s || \
			{ echo "$(RED)❌ Ingress Controller rollout failed$(RESET)"; exit 1; }; \
		kubectl wait --namespace ingress-nginx \
			--for=condition=ready pod \
			--selector=app.kubernetes.io/component=controller \
			--timeout=30s || echo "$(YELLOW)⚠️  Pod may still be starting$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Ingress Controller installed!$(RESET)"

ingress-config: ## Configure Ingress rules for ArgoCD
	@echo "$(CYAN)Configuring Ingress rules...$(RESET)"
	$(call execute_cmd, kubectl apply -f ingress/argocd/argocd-cmd-params-cm-patch.yaml)
	$(call execute_cmd, kubectl apply -f ingress/argocd/argocd-ingress.yaml)
	$(call execute_cmd, kubectl rollout restart deployment argocd-server -n argocd)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		kubectl wait --for=condition=available --timeout=60s deployment/argocd-server -n argocd || \
			echo "$(YELLOW)⚠️  ArgoCD may still be restarting$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Ingress configured!$(RESET)"
	@echo "$(YELLOW)📌 Remember to add '127.0.0.1 argocd.local' to /etc/hosts$(RESET)"

#=============================================================================
# LOCAL DEVELOPMENT
#=============================================================================
build-local: ## Build Docker image for local registry
	@echo "$(CYAN)🔨 Building local image...$(RESET)"
	$(call execute_cmd, docker build -t localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA) .)
	@echo "$(GREEN)✅ Image built: localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA)$(RESET)"

develop-local: ## 💻 Development workflow (build+push+update+sync)
	@echo "$(CYAN)💻 Starting local development workflow...$(RESET)"
	@$(MAKE) build-local
	@echo "$(CYAN)📤 Pushing to local registry...$(RESET)"
	$(call execute_cmd, docker push localhost:$(REGISTRY_PORT)/podinfo:dev-$(SHA))
	@echo "$(CYAN)📝 Updating kustomization...$(RESET)"
	$(call execute_cmd, yq -i '.images[0].newTag = "dev-$(SHA)"' k8s/podinfo/overlays/dev-local/kustomization.yaml)
	@echo "$(CYAN)🔄 Syncing ArgoCD application...$(RESET)"
	$(call execute_cmd, argocd app sync podinfo-local --grpc-web 2>/dev/null || kubectl -n argocd patch app podinfo-local --type merge -p '{"operation":{"sync":{}}}' 2>/dev/null || echo "$(YELLOW)⚠️  Manual sync may be required$(RESET)")
	@echo "$(GREEN)✅ Development workflow complete!$(RESET)"


#=============================================================================
# GHCR RELEASE
#=============================================================================
release-ghcr: ## ☁️ Release to GHCR (add+commit+sync+push)
	@echo "$(CYAN)☁️  Starting GHCR release workflow...$(RESET)"
	@echo "$(CYAN)📝 Adding local changes...$(RESET)"
	$(call execute_cmd, git add .)
	@echo "$(CYAN)📝 Committing changes...$(RESET)"
	$(call execute_cmd, git commit -m "$(MSG)")
	@echo "$(CYAN)🔄 Syncing with remote...$(RESET)"
	$(call execute_cmd, git pull --no-rebase origin main || echo "$(YELLOW)⚠️  Sync failed - manual merge may be required$(RESET)")
	@echo "$(CYAN)📤 Pushing to remote...$(RESET)"
	$(call execute_cmd, git push origin main)
	@echo "$(GREEN)✅ GHCR release complete!$(RESET)"
	@echo "$(CYAN)💡 GitHub Actions will now build and push the image$(RESET)"
	@echo "$(CYAN)💡 ArgoCD will automatically deploy the new version$(RESET)"

#=============================================================================
# DEPLOYMENT COMMANDS
#=============================================================================
deploy-app-local: ## Deploy local podinfo application (initial setup only)
	@echo "$(CYAN)🚀 Deploying local application...$(RESET)"
	$(call execute_cmd, kubectl apply -f gitops/argocd/apps/podinfo-local.yaml)
	@echo "$(GREEN)✅ Local application deployed!$(RESET)"

deploy-app-ghcr: ## Deploy GHCR podinfo application
	@echo "$(CYAN)☁️  Deploying GHCR application...$(RESET)"
	$(call execute_cmd, $(call create_namespace,demo-ghcr))
	$(call execute_cmd, kubectl apply -f gitops/argocd/apps/podinfo-ghcr.yaml)
	@echo "$(GREEN)✅ GHCR application deployed!$(RESET)"

deploy-monitoring: ## Deploy Prometheus and Grafana monitoring stack
	@echo "$(CYAN)📊 Deploying monitoring stack...$(RESET)"
	$(call execute_cmd, kubectl apply -f monitoring/kube-prometheus-stack/application.yaml)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		kubectl wait --for=condition=Synced application/kube-prometheus-stack -n argocd --timeout=$(WAIT_TIMEOUT) || \
			echo "$(YELLOW)⚠️  Monitoring stack may still be syncing$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Monitoring stack deployed!$(RESET)"

#=============================================================================
# UTILITIES
#=============================================================================
check-git-status: ## Check for uncommitted changes (used by GHCR workflow)
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "$(YELLOW)⚠️  Warning: You have uncommitted changes$(RESET)"; \
		echo "Files with changes:"; \
		git status --short; \
		read -p "Continue anyway? [y/N]: " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "$(RED)Aborted$(RESET)"; \
			exit 1; \
		fi; \
	fi

#=============================================================================
# OPERATIONS & MONITORING
#=============================================================================
verify: ## Check system status and health
	@echo "$(CYAN)🔍 System Verification$(RESET)"
	@echo "$(CYAN)=====================$(RESET)"
	@echo ""
	@echo "$(CYAN)Cluster Status:$(RESET)"
	@kubectl get nodes 2>/dev/null && echo "$(GREEN)✅ Cluster is running$(RESET)" || echo "$(RED)❌ Cluster not found$(RESET)"
	@echo ""
	@echo "$(CYAN)Core Components:$(RESET)"
	@kubectl get pods -n argocd --no-headers 2>/dev/null | grep -v Running | grep -v Completed > /dev/null && \
		echo "$(YELLOW)⚠️  Some ArgoCD pods not ready$(RESET)" || echo "$(GREEN)✅ ArgoCD running$(RESET)" || echo "$(RED)❌ ArgoCD not installed$(RESET)"
	@kubectl get pods -n ingress-nginx 2>/dev/null | grep Running > /dev/null && \
		echo "$(GREEN)✅ Ingress controller running$(RESET)" || echo "$(RED)❌ Ingress not installed$(RESET)"
	@kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | xargs -I {} test {} -gt 0 && \
		echo "$(GREEN)✅ Monitoring stack running$(RESET)" || echo "$(YELLOW)⚠️  Monitoring not installed$(RESET)"
	@echo ""
	@echo "$(CYAN)Applications:$(RESET)"
	@kubectl get applications -n argocd 2>/dev/null | tail -n +2 | while read app rest; do \
		echo "  • $$app"; \
	done || echo "$(YELLOW)No applications deployed$(RESET)"
	@echo ""
	@echo "$(CYAN)Service Health:$(RESET)"
	@curl -sf -o /dev/null http://argocd.local/api/v1/version 2>/dev/null && \
		echo "$(GREEN)✅ ArgoCD API healthy$(RESET)" || echo "$(YELLOW)⚠️  ArgoCD not accessible (check /etc/hosts)$(RESET)"
	@if [ "$(DETAILED)" = "1" ]; then \
		echo ""; \
		echo "$(CYAN)Detailed Pod Status:$(RESET)"; \
		kubectl get pods -A | grep -E "(argocd|monitoring|demo-)" || true; \
	fi

access: ## Show all access URLs and credentials
	@echo "$(CYAN)🌐 Service Access Information$(RESET)"
	@echo "$(CYAN)=============================$(RESET)"
	@echo ""
	@echo "$(GREEN)Service URLs:$(RESET)"
	@echo "  ArgoCD:     http://argocd.local"
	@echo "  Grafana:    kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3001:80"
	@echo "  Prometheus: kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090"
	@echo ""
	@echo "$(GREEN)Credentials:$(RESET)"
	@echo "  ArgoCD:     admin / $(ARGOCD_PASSWORD)"
	@echo "  Grafana:    admin / $(GRAFANA_PASSWORD)"
	@echo ""
	@echo "$(YELLOW)📌 Note: Ensure /etc/hosts contains: 127.0.0.1 argocd.local$(RESET)"

logs: ## Show ArgoCD server logs
	@echo "$(CYAN)📜 ArgoCD Server Logs (last 50 lines)$(RESET)"
	@kubectl logs -n argocd deployment/argocd-server --tail=50 2>/dev/null || echo "$(RED)❌ ArgoCD not found$(RESET)"
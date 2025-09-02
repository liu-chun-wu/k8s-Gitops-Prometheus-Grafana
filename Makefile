# K8s GitOps Demo - Optimized Makefile v3
.PHONY: help quickstart quickstart-local quickstart-ghcr clean \
        cluster-create cluster-delete registry-setup registry-test \
        argocd-install argocd-config ingress-install ingress-config \
        build-local develop-local \
        release-ghcr check-sync-strict wait-for-actions sync-actions-changes release-status \
        deploy-app-local deploy-app-ghcr deploy-monitoring \
        alert-install alert-uninstall alert-update-webhook alert-reinstall alert-status \
        test-alert-instant clean-instant-alerts test-alert clean-test-alerts \
        setup-discord deploy-alerting \
        status verify access logs check-git-status pause-services resume-services

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
	@echo "$(GREEN)🔔 Alert Management$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)alert-install$(RESET)      Install alerting system with Discord"
	@echo "  $(CYAN)alert-uninstall$(RESET)    Remove alerting system"
	@echo "  $(CYAN)alert-update-webhook$(RESET) Update Discord webhook URL"
	@echo "  $(CYAN)alert-reinstall$(RESET)    Reinstall (for webhook changes)"
	@echo "  $(CYAN)alert-status$(RESET)       Check alerting system status"
	@echo "  $(CYAN)test-alert-instant$(RESET) Deploy instantly triggering test"
	@echo ""
	@echo "$(GREEN)📋 Operations$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@echo "  $(CYAN)status$(RESET)             Check system status & health"
	@echo "  $(CYAN)access$(RESET)             Show URLs and credentials"
	@echo "  $(CYAN)logs$(RESET)               View ArgoCD server logs"
	@echo "  $(CYAN)pause-services$(RESET)     Pause all services (keep data)"
	@echo "  $(CYAN)resume-services$(RESET)    Resume all services"
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
	@$(MAKE) status
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
	@$(MAKE) status
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

# 嚴格檢查同步狀態
check-sync-strict: ## Check sync status with strict safety checks
	@echo "$(CYAN)🔍 檢查本地與遠端同步狀態...$(RESET)"
	@git fetch origin main
	@LOCAL_CHANGES=$$(git status --porcelain); \
	BEHIND=$$(git rev-list HEAD..origin/main --count); \
	AHEAD=$$(git rev-list origin/main..HEAD --count); \
	if [ "$$BEHIND" -gt 0 ] && [ -n "$$LOCAL_CHANGES" ]; then \
		echo "$(RED)❌ 錯誤：本地有未提交變更且落後於遠端$(RESET)"; \
		echo "$(YELLOW)本地落後 $$BEHIND 個提交$(RESET)"; \
		echo "$(YELLOW)請先手動處理：$(RESET)"; \
		echo "  1. git stash        # 暫存本地變更"; \
		echo "  2. git pull --rebase origin main"; \
		echo "  3. git stash pop    # 恢復變更"; \
		echo "  4. 解決任何衝突後再執行 make release-ghcr"; \
		exit 1; \
	elif [ "$$BEHIND" -gt 0 ]; then \
		echo "$(YELLOW)⚠️  本地落後於遠端 $$BEHIND 個提交$(RESET)"; \
		echo "$(CYAN)📥 自動同步遠端變更...$(RESET)"; \
		git pull --rebase origin main || exit 1; \
		echo "$(GREEN)✅ 同步完成$(RESET)"; \
	elif [ "$$AHEAD" -gt 0 ]; then \
		echo "$(YELLOW)⚠️  本地領先遠端 $$AHEAD 個提交（尚未推送）$(RESET)"; \
	else \
		echo "$(GREEN)✅ 本地與遠端已同步$(RESET)"; \
	fi

# 等待 GitHub Actions 完成
wait-for-actions: ## Wait for GitHub Actions to complete
	@echo "$(CYAN)⏳ 等待 GitHub Actions 完成...$(RESET)"
	@CURRENT_SHA=$$(git rev-parse HEAD); \
	echo "$(CYAN)監控 commit: $${CURRENT_SHA:0:7}$(RESET)"; \
	sleep 5; \
	ATTEMPTS=0; \
	while [ $$ATTEMPTS -lt 60 ]; do \
		STATUS=$$(gh run list --workflow=release-ghcr.yml --limit 1 --json status,headSha \
			| jq -r --arg sha "$$CURRENT_SHA" '.[] | select(.headSha==$$sha) | .status' 2>/dev/null); \
		if [ "$$STATUS" = "completed" ]; then \
			CONCLUSION=$$(gh run list --workflow=release-ghcr.yml --limit 1 --json conclusion,headSha \
				| jq -r --arg sha "$$CURRENT_SHA" '.[] | select(.headSha==$$sha) | .conclusion' 2>/dev/null); \
			if [ "$$CONCLUSION" = "success" ]; then \
				echo "$(GREEN)✅ GitHub Actions 成功完成！$(RESET)"; \
			else \
				echo "$(RED)❌ GitHub Actions 失敗: $$CONCLUSION$(RESET)"; \
				exit 1; \
			fi; \
			break; \
		elif [ "$$STATUS" = "failure" ] || [ "$$STATUS" = "cancelled" ]; then \
			echo "$(RED)❌ GitHub Actions 狀態: $$STATUS$(RESET)"; \
			exit 1; \
		elif [ -n "$$STATUS" ]; then \
			echo "⏳ 狀態: $$STATUS - 等待中..."; \
		fi; \
		sleep 10; \
		ATTEMPTS=$$((ATTEMPTS + 1)); \
	done; \
	if [ $$ATTEMPTS -eq 60 ]; then \
		echo "$(YELLOW)⚠️  等待超時，請手動檢查 GitHub Actions$(RESET)"; \
	fi

# 同步 Actions 產生的變更
sync-actions-changes: ## Sync changes made by GitHub Actions
	@echo "$(CYAN)📥 同步 GitHub Actions 的變更...$(RESET)"
	@git fetch origin main
	@git pull --rebase origin main || { \
		echo "$(RED)❌ 同步失敗，請手動執行 git pull$(RESET)"; \
		exit 1; \
	}
	@echo "$(GREEN)✅ 已同步最新變更$(RESET)"

# 顯示當前狀態
release-status: ## Show current release status
	@echo "$(CYAN)📊 Release 狀態檢查$(RESET)"
	@echo "$(CYAN)========================$(RESET)"
	@git fetch origin main 2>/dev/null
	@echo "$(CYAN)本地分支:$(RESET) $$(git branch --show-current)"
	@echo "$(CYAN)最新提交:$(RESET) $$(git log -1 --oneline)"
	@BEHIND=$$(git rev-list HEAD..origin/main --count); \
	AHEAD=$$(git rev-list origin/main..HEAD --count); \
	if [ "$$BEHIND" -gt 0 ]; then \
		echo "$(YELLOW)落後遠端:$(RESET) $$BEHIND 個提交"; \
	fi; \
	if [ "$$AHEAD" -gt 0 ]; then \
		echo "$(YELLOW)領先遠端:$(RESET) $$AHEAD 個提交（未推送）"; \
	fi; \
	if [ "$$BEHIND" -eq 0 ] && [ "$$AHEAD" -eq 0 ]; then \
		echo "$(GREEN)同步狀態:$(RESET) ✅ 已同步"; \
	fi
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "$(YELLOW)本地變更:$(RESET) 有未提交的變更"; \
		git status --short; \
	else \
		echo "$(GREEN)工作區:$(RESET) 乾淨"; \
	fi
	@echo ""
	@echo "$(CYAN)GitHub Actions 最新狀態:$(RESET)"
	@gh run list --workflow=release-ghcr.yml --limit 3 2>/dev/null || echo "  需要 gh CLI 來顯示 workflow 狀態"

release-ghcr: ## ☁️ Release to GHCR with safety checks
	@echo "$(CYAN)☁️  Starting GHCR release workflow...$(RESET)"
	
	# Step 1: 嚴格檢查同步狀態
	@$(MAKE) check-sync-strict
	
	# Step 2: 檢查是否有變更需要提交
	@if [ -z "$$(git status --porcelain)" ]; then \
		echo "$(YELLOW)⚠️  沒有變更需要提交$(RESET)"; \
		echo "$(CYAN)如需觸發新構建，使用：git commit --allow-empty -m 'trigger build'$(RESET)"; \
		exit 0; \
	fi
	
	# Step 3: 提交本地變更
	@echo "$(CYAN)📝 添加並提交變更...$(RESET)"
	$(call execute_cmd, git add .)
	$(call execute_cmd, git commit -m "$(MSG)")
	
	# Step 4: 推送到遠端
	@echo "$(CYAN)📤 推送到遠端...$(RESET)"
	@git push origin main || { \
		echo "$(RED)❌ 推送失敗$(RESET)"; \
		echo "$(YELLOW)可能的原因：$(RESET)"; \
		echo "  • 遠端有新的提交（執行 git pull --rebase 後重試）"; \
		echo "  • 沒有推送權限"; \
		exit 1; \
	}
	
	# Step 5: 等待 GitHub Actions 完成
	@echo "$(CYAN)⏳ 等待 GitHub Actions 完成...$(RESET)"
	@$(MAKE) wait-for-actions || echo "$(YELLOW)⚠️  無法確認 Actions 狀態$(RESET)"
	
	# Step 6: 同步 Actions 的 image tag 更新
	@echo "$(CYAN)📥 同步 GitHub Actions 的 tag 更新...$(RESET)"
	@git pull --rebase origin main || { \
		echo "$(YELLOW)⚠️  同步失敗，請手動執行 git pull$(RESET)"; \
	}
	
	@echo "$(GREEN)✅ GHCR release 完成！$(RESET)"
	@echo "$(CYAN)💡 新的 image tag 已更新在 kustomization.yaml$(RESET)"
	@echo "$(CYAN)💡 ArgoCD 將自動部署新版本$(RESET)"

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
# ALERTING COMMANDS
#=============================================================================
alert-install: ## Install complete alerting system with Discord webhook
	@echo "$(CYAN)🔔 Installing alerting system...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found!$(RESET)"; \
		echo "$(YELLOW)Please run: cp .env.example .env$(RESET)"; \
		echo "$(YELLOW)Then edit .env with your Discord webhook URL$(RESET)"; \
		exit 1; \
	fi
	$(call execute_cmd, ./scripts/manage-alerts.sh install)
	@echo "$(GREEN)✅ Alerting system installed!$(RESET)"

alert-uninstall: ## Completely remove alerting system
	@echo "$(YELLOW)🗑️  Uninstalling alerting system...$(RESET)"
	$(call execute_cmd, ./scripts/manage-alerts.sh uninstall)
	@echo "$(GREEN)✅ Alerting system removed!$(RESET)"

alert-update-webhook: ## Update Discord webhook URL only
	@echo "$(CYAN)🔄 Updating Discord webhook...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found!$(RESET)"; \
		echo "$(YELLOW)Please run: cp .env.example .env$(RESET)"; \
		echo "$(YELLOW)Then edit .env with your Discord webhook URL$(RESET)"; \
		exit 1; \
	fi
	$(call execute_cmd, ./scripts/manage-alerts.sh update-webhook)
	@echo "$(GREEN)✅ Discord webhook updated!$(RESET)"

alert-reinstall: ## Reinstall alerting system (for webhook changes)
	@echo "$(CYAN)♻️  Reinstalling alerting system...$(RESET)"
	@if [ ! -f .env ]; then \
		echo "$(RED)❌ .env file not found!$(RESET)"; \
		echo "$(YELLOW)Please run: cp .env.example .env$(RESET)"; \
		echo "$(YELLOW)Then edit .env with your new Discord webhook URL$(RESET)"; \
		exit 1; \
	fi
	$(call execute_cmd, ./scripts/manage-alerts.sh reinstall)
	@echo "$(GREEN)✅ Alerting system reinstalled with new webhook!$(RESET)"

alert-status: ## Check alerting system status
	@echo "$(CYAN)📊 Checking alerting system status...$(RESET)"
	@./scripts/manage-alerts.sh status

test-alert-instant: ## Deploy instantly triggering test alerts
	@echo "$(CYAN)🚀 Deploying instant test alerts...$(RESET)"
	$(call execute_cmd, kubectl apply -f monitoring/alertmanager/test-alert-instant.yaml)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		echo "$(GREEN)✅ Instant test alert deployed!$(RESET)"; \
		echo ""; \
		echo "$(CYAN)⏱️  Expected trigger times:$(RESET)"; \
		echo "  • InstantTestAlert: $(GREEN)Immediately$(RESET)"; \
		echo "  • TestAlertInfo10s: $(YELLOW)After 10 seconds$(RESET)"; \
		echo "  • TestAlertWarning30s: $(YELLOW)After 30 seconds$(RESET)"; \
		echo "  • TimeBasedTestAlert: $(YELLOW)After 1 minute$(RESET)"; \
		echo ""; \
		echo "$(CYAN)💬 Check your Discord channel for notifications$(RESET)"; \
		echo ""; \
		echo "$(YELLOW)Monitor alerts:$(RESET)"; \
		echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"; \
		echo "  Open: http://localhost:9090/alerts"; \
		echo ""; \
		echo "$(CYAN)💡 Run 'make clean-instant-alerts' when done testing$(RESET)"; \
	fi

clean-instant-alerts: ## Remove instant test alert rules
	@echo "$(CYAN)🧹 Cleaning up instant test alerts...$(RESET)"
	$(call execute_cmd, kubectl delete -f monitoring/alertmanager/test-alert-instant.yaml --ignore-not-found=true)
	@echo "$(GREEN)✅ Instant test alerts cleaned up!$(RESET)"

# Legacy commands (kept for backward compatibility)
setup-discord: ## [DEPRECATED] Use 'make alert-install' instead
	@echo "$(YELLOW)⚠️  This command is deprecated. Use 'make alert-install' instead$(RESET)"
	@$(MAKE) alert-install

deploy-alerting: ## [DEPRECATED] Use 'make alert-install' instead
	@echo "$(YELLOW)⚠️  This command is deprecated. Use 'make alert-install' instead$(RESET)"
	@$(MAKE) alert-install

test-alert: ## Send test alert to Discord (1-2 minute delay)
	@echo "$(CYAN)🧪 Deploying test alert (1-2 minute delay)...$(RESET)"
	$(call execute_cmd, kubectl apply -f monitoring/alertmanager/test-alert.yaml)
	@if [ "$(DRY_RUN)" != "1" ]; then \
		echo "$(CYAN)⏳ Test alert will trigger in 1-2 minutes...$(RESET)"; \
		echo "$(CYAN)💬 Check your Discord channel for notifications$(RESET)"; \
		echo ""; \
		echo "$(YELLOW)監控警報狀態:$(RESET)"; \
		echo "  Prometheus: http://localhost:9090/alerts"; \
		echo "  AlertManager: http://localhost:9093"; \
		echo ""; \
		echo "$(YELLOW)Port forwarding (在新終端執行):$(RESET)"; \
		echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"; \
		echo "  kubectl port-forward -n monitoring svc/kube-prometheus-stack-alertmanager 9093:9093"; \
		echo ""; \
		echo "$(CYAN)💡 Run 'make clean-test-alerts' when done testing$(RESET)"; \
	fi
	@echo "$(GREEN)✅ Test alert deployed!$(RESET)"

clean-test-alerts: ## Remove all test alert rules
	@echo "$(CYAN)🧹 Cleaning up all test alerts...$(RESET)"
	$(call execute_cmd, kubectl delete -f monitoring/alertmanager/test-alert.yaml --ignore-not-found=true)
	$(call execute_cmd, kubectl delete -f monitoring/alertmanager/test-alert-instant.yaml --ignore-not-found=true)
	@echo "$(GREEN)✅ All test alerts cleaned up!$(RESET)"

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
status: ## Check system status and health
	@echo "$(CYAN)🔍 System Status$(RESET)"
	@echo "$(CYAN)=================$(RESET)"
	@echo ""
	@echo "$(CYAN)Cluster Status:$(RESET)"
	@kubectl get nodes 2>/dev/null && echo "$(GREEN)✅ Cluster is running$(RESET)" || echo "$(RED)❌ Cluster not found$(RESET)"
	@echo ""
	@echo "$(CYAN)Core Components:$(RESET)"
	@if kubectl get ns argocd &>/dev/null; then \
		RUNNING=$$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0); \
		TOTAL=$$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | xargs || echo 0); \
		if [ "$$RUNNING" -gt 0 ]; then \
			if [ "$$RUNNING" -eq "$$TOTAL" ]; then \
				echo "$(GREEN)✅ ArgoCD running ($$RUNNING/$$TOTAL pods)$(RESET)"; \
			else \
				echo "$(YELLOW)⚠️  ArgoCD partially ready ($$RUNNING/$$TOTAL pods)$(RESET)"; \
			fi; \
		else \
			echo "$(RED)❌ ArgoCD pods not ready$(RESET)"; \
		fi; \
	else \
		echo "$(RED)❌ ArgoCD not installed$(RESET)"; \
	fi
	@if kubectl get ns ingress-nginx &>/dev/null; then \
		kubectl get pods -n ingress-nginx 2>/dev/null | grep -q Running && \
			echo "$(GREEN)✅ Ingress controller running$(RESET)" || \
			echo "$(RED)❌ Ingress controller not ready$(RESET)"; \
	else \
		echo "$(RED)❌ Ingress not installed$(RESET)"; \
	fi
	@if kubectl get ns monitoring &>/dev/null; then \
		PODS=$$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | xargs); \
		if [ "$$PODS" -gt 0 ]; then \
			echo "$(GREEN)✅ Monitoring stack running ($$PODS pods)$(RESET)"; \
		else \
			echo "$(YELLOW)⚠️  Monitoring namespace exists but no pods$(RESET)"; \
		fi; \
	else \
		echo "$(YELLOW)⚠️  Monitoring not installed$(RESET)"; \
	fi
	@echo ""
	@echo "$(CYAN)Applications:$(RESET)"
	@kubectl get applications -n argocd 2>/dev/null | tail -n +2 | while read app rest; do \
		echo "  • $$app"; \
	done || echo "$(YELLOW)No applications deployed$(RESET)"
	@echo ""
	@echo "$(CYAN)Service Health:$(RESET)"
	@curl -sf -o /dev/null http://argocd.local/api/version 2>/dev/null && \
		echo "$(GREEN)✅ ArgoCD API healthy$(RESET)" || echo "$(YELLOW)⚠️  ArgoCD not accessible (check /etc/hosts)$(RESET)"
	@if [ "$(DETAILED)" = "1" ]; then \
		echo ""; \
		echo "$(CYAN)Detailed Pod Status:$(RESET)"; \
		kubectl get pods -A | grep -E "(argocd|monitoring|demo-)" || true; \
	fi

verify: ## Alias for status (deprecated, use 'make status' instead)
	@$(MAKE) status

access: ## Show all access URLs and credentials
	@echo "$(CYAN)🌐 Service Access Information$(RESET)"
	@echo "$(CYAN)=============================$(RESET)"
	@echo ""
	@echo "$(GREEN)Service URLs:$(RESET)"
	@echo "  ArgoCD:       http://argocd.local"
	@echo "  Prometheus:   http://localhost:30090"
	@echo "  Grafana:      http://localhost:30301"
	@echo "  AlertManager: http://localhost:30093"
	@echo ""
	@echo "$(GREEN)Credentials:$(RESET)"
	@echo "  ArgoCD:     admin / $(ARGOCD_PASSWORD)"
	@echo "  Grafana:    admin / $(GRAFANA_PASSWORD)"
	@echo ""
	@echo "$(YELLOW)📌 Note: Ensure /etc/hosts contains: 127.0.0.1 argocd.local$(RESET)"

logs: ## Show ArgoCD server logs
	@echo "$(CYAN)📜 ArgoCD Server Logs (last 50 lines)$(RESET)"
	@kubectl logs -n argocd deployment/argocd-server --tail=50 2>/dev/null || echo "$(RED)❌ ArgoCD not found$(RESET)"

pause-services: ## Pause all services but keep data
	@echo "$(CYAN)⏸️  Pausing all services...$(RESET)"
	@echo "$(YELLOW)This will scale down all deployments and statefulsets to 0 replicas$(RESET)"
	@echo "$(YELLOW)All data and configurations will be preserved$(RESET)"
	# Pause ArgoCD
	$(call execute_cmd, kubectl scale deployment -n argocd --replicas=0 --all 2>/dev/null || true)
	$(call execute_cmd, kubectl scale statefulset -n argocd --replicas=0 --all 2>/dev/null || true)
	# Pause Monitoring
	$(call execute_cmd, kubectl scale deployment -n monitoring --replicas=0 --all 2>/dev/null || true)
	$(call execute_cmd, kubectl scale statefulset -n monitoring --replicas=0 --all 2>/dev/null || true)
	# Pause Demo Applications
	$(call execute_cmd, kubectl scale deployment -n demo-ghcr --replicas=0 --all 2>/dev/null || true)
	$(call execute_cmd, kubectl scale deployment -n demo-local --replicas=0 --all 2>/dev/null || true)
	# Pause Ingress Controller
	$(call execute_cmd, kubectl scale deployment -n ingress-nginx --replicas=0 --all 2>/dev/null || true)
	@echo "$(GREEN)✅ All services paused successfully!$(RESET)"
	@echo "$(CYAN)Use 'make resume-services' to restart$(RESET)"

resume-services: ## Resume all services with health checks
	@echo "$(CYAN)▶️  Resuming all services...$(RESET)"
	# Resume ArgoCD
	$(call execute_cmd, kubectl scale deployment -n argocd --replicas=1 --all 2>/dev/null || true)
	$(call execute_cmd, kubectl scale statefulset -n argocd --replicas=1 --all 2>/dev/null || true)
	# Resume Monitoring
	$(call execute_cmd, kubectl scale deployment -n monitoring --replicas=1 --all 2>/dev/null || true)
	$(call execute_cmd, kubectl scale statefulset -n monitoring --replicas=1 --all 2>/dev/null || true)
	# Resume Demo Applications (usually 2 replicas)
	$(call execute_cmd, kubectl scale deployment ghcr-podinfo -n demo-ghcr --replicas=2 2>/dev/null || true)
	$(call execute_cmd, kubectl scale deployment local-podinfo -n demo-local --replicas=2 2>/dev/null || true)
	# Resume Ingress Controller
	$(call execute_cmd, kubectl scale deployment ingress-nginx-controller -n ingress-nginx --replicas=1 2>/dev/null || true)
	@echo ""
	@echo "$(CYAN)⏳ Waiting for services to be ready...$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	# Wait for ArgoCD
	@echo "$(CYAN)Checking ArgoCD...$(RESET)"
	@kubectl wait --for=condition=available --timeout=120s \
		deployment/argocd-server -n argocd 2>/dev/null && \
		echo "$(GREEN)  ✓ ArgoCD server ready$(RESET)" || \
		echo "$(YELLOW)  ⚠️  ArgoCD server timeout (may still be starting)$(RESET)"
	@kubectl wait --for=condition=ready --timeout=60s \
		statefulset/argocd-application-controller -n argocd 2>/dev/null && \
		echo "$(GREEN)  ✓ ArgoCD application controller ready$(RESET)" || \
		echo "$(YELLOW)  ⚠️  ArgoCD controller timeout$(RESET)"
	# Wait for Ingress Controller
	@echo "$(CYAN)Checking Ingress Controller...$(RESET)"
	@kubectl wait --for=condition=ready pod \
		-l app.kubernetes.io/component=controller \
		-n ingress-nginx --timeout=60s 2>/dev/null && \
		echo "$(GREEN)  ✓ Ingress controller ready$(RESET)" || \
		echo "$(YELLOW)  ⚠️  Ingress controller timeout$(RESET)"
	# Wait for Monitoring Stack
	@echo "$(CYAN)Checking Monitoring Stack...$(RESET)"
	@if kubectl get deployment kube-prometheus-stack-grafana -n monitoring &>/dev/null; then \
		kubectl wait --for=condition=available --timeout=120s \
			deployment/kube-prometheus-stack-grafana -n monitoring 2>/dev/null && \
			echo "$(GREEN)  ✓ Grafana ready$(RESET)" || \
			echo "$(YELLOW)  ⚠️  Grafana timeout$(RESET)"; \
		kubectl wait --for=condition=ready --timeout=120s \
			statefulset/prometheus-kube-prometheus-stack-prometheus -n monitoring 2>/dev/null && \
			echo "$(GREEN)  ✓ Prometheus ready$(RESET)" || \
			echo "$(YELLOW)  ⚠️  Prometheus timeout$(RESET)"; \
	else \
		echo "$(YELLOW)  ⚠️  Monitoring stack not deployed$(RESET)"; \
	fi
	# Check ArgoCD API
	@echo "$(CYAN)Verifying ArgoCD API...$(RESET)"
	@RETRY=0; MAX_RETRY=30; \
	while [ $$RETRY -lt $$MAX_RETRY ]; do \
		if curl -sf -o /dev/null http://argocd.local/api/version 2>/dev/null; then \
			echo "$(GREEN)  ✓ ArgoCD API is responding$(RESET)"; \
			break; \
		fi; \
		RETRY=$$((RETRY + 1)); \
		if [ $$RETRY -eq $$MAX_RETRY ]; then \
			echo "$(YELLOW)  ⚠️  ArgoCD API not responding (check /etc/hosts)$(RESET)"; \
		else \
			printf "\r  Waiting for ArgoCD API... ($$RETRY/$$MAX_RETRY)"; \
			sleep 2; \
		fi; \
	done
	# Show service status summary
	@echo ""
	@echo "$(CYAN)📊 Service Status Summary:$(RESET)"
	@echo "$(CYAN)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(RESET)"
	@ARGOCD_PODS=$$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0); \
	ARGOCD_TOTAL=$$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l | xargs || echo 0); \
	echo "  ArgoCD:     $$ARGOCD_PODS/$$ARGOCD_TOTAL pods running"
	@MONITORING_PODS=$$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c Running || echo 0); \
	MONITORING_TOTAL=$$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l | xargs || echo 0); \
	if [ "$$MONITORING_TOTAL" -gt 0 ]; then \
		echo "  Monitoring: $$MONITORING_PODS/$$MONITORING_TOTAL pods running"; \
	else \
		echo "  Monitoring: not deployed"; \
	fi
	@INGRESS_PODS=$$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | grep -c Running || echo 0); \
	INGRESS_TOTAL=$$(kubectl get pods -n ingress-nginx --no-headers 2>/dev/null | wc -l | xargs || echo 0); \
	echo "  Ingress:    $$INGRESS_PODS/$$INGRESS_TOTAL pods running"
	@DEMO_GHCR_PODS=$$(kubectl get pods -n demo-ghcr --no-headers 2>/dev/null | grep -c Running || echo 0); \
	DEMO_LOCAL_PODS=$$(kubectl get pods -n demo-local --no-headers 2>/dev/null | grep -c Running || echo 0); \
	if [ "$$DEMO_GHCR_PODS" -gt 0 ] || [ "$$DEMO_LOCAL_PODS" -gt 0 ]; then \
		echo "  Demo Apps:  $$DEMO_GHCR_PODS (ghcr) / $$DEMO_LOCAL_PODS (local) pods"; \
	fi
	@echo ""
	@echo "$(GREEN)✅ Services resumed with health checks completed!$(RESET)"
	@echo "$(CYAN)Run 'make status' for detailed status or 'make access' for URLs$(RESET)"
#!/bin/bash
set -e

# Script to create a kind cluster with optional local Docker registry
# Based on: https://kind.sigs.k8s.io/docs/user/local-registry/

CLUSTER_NAME="${CLUSTER_NAME:-gitops-demo}"
REGISTRY_NAME="${REGISTRY_NAME:-kind-registry}"
REGISTRY_PORT="${REGISTRY_PORT:-5001}"
SKIP_REGISTRY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-registry)
            SKIP_REGISTRY=true
            shift
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --no-registry     Skip creating local Docker registry"
            echo "  --cluster-name    Specify cluster name (default: gitops-demo)"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo "🔍 Checking prerequisites..."
for cmd in docker kind kubectl; do
    if ! command_exists "$cmd"; then
        echo "❌ $cmd is not installed. Please install it first."
        exit 1
    fi
done
echo "✅ All prerequisites met"

# Create registry if needed and not skipped
if [ "$SKIP_REGISTRY" = false ]; then
    if [ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY_NAME}" 2>/dev/null || true)" != 'true' ]; then
        echo "📦 Creating local Docker registry..."
        docker run \
            -d --restart=always -p "127.0.0.1:${REGISTRY_PORT}:5000" \
            --network bridge \
            --name "${REGISTRY_NAME}" \
            registry:2
        echo "✅ Registry created at localhost:${REGISTRY_PORT}"
    else
        echo "ℹ️  Registry ${REGISTRY_NAME} already exists"
    fi
else
    echo "ℹ️  Skipping local registry creation (--no-registry flag)"
fi

# Create kind cluster
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "⚠️  Cluster ${CLUSTER_NAME} already exists. Delete it? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "🗑️  Deleting existing cluster..."
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo "ℹ️  Using existing cluster"
        exit 0
    fi
fi

# Determine which config file to use and create cluster
if [ "$SKIP_REGISTRY" = false ]; then
    echo "🚀 Creating kind cluster with local registry support..."
    kind create cluster --name "${CLUSTER_NAME}" --config=../kind-cluster.yaml
    
    # Get the registry network
    if [ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' "${REGISTRY_NAME}")" = 'null' ]; then
        echo "🔌 Connecting registry to cluster network..."
        docker network connect "kind" "${REGISTRY_NAME}"
    fi
else
    echo "🚀 Creating kind cluster without local registry..."
    # Use the dedicated no-registry config file
    kind create cluster --name "${CLUSTER_NAME}" --config=../kind-cluster-no-registry.yaml
fi

# Document the local registry if enabled
if [ "$SKIP_REGISTRY" = false ]; then
    echo "📝 Documenting the registry in cluster..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
fi

# Test the registry if enabled and show appropriate message
if [ "$SKIP_REGISTRY" = false ]; then
    echo "🧪 Testing registry connectivity..."
    docker pull busybox:latest
    docker tag busybox:latest localhost:${REGISTRY_PORT}/busybox:test
    docker push localhost:${REGISTRY_PORT}/busybox:test
    
    echo "✅ Kind cluster '${CLUSTER_NAME}' created with local registry at localhost:${REGISTRY_PORT}"
    echo ""
    echo "📌 Quick start:"
    echo "  - Build and push: docker build -t localhost:${REGISTRY_PORT}/myapp:tag . && docker push localhost:${REGISTRY_PORT}/myapp:tag"
    echo "  - Use in K8s: image: localhost:${REGISTRY_PORT}/myapp:tag"
    echo "  - From inside cluster: image: kind-registry:5000/myapp:tag"
else
    echo "✅ Kind cluster '${CLUSTER_NAME}' created without local registry"
    echo ""
    echo "📌 Quick start for GHCR:"
    echo "  - Build and push: docker build -t ghcr.io/<username>/myapp:tag . && docker push ghcr.io/<username>/myapp:tag"
    echo "  - Configure GHCR secrets in your cluster"
    echo "  - Deploy using ArgoCD applications"
fi
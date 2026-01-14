.PHONY: help cluster install uninstall status clean verify

# Default values
CLUSTER_NAME ?= fleetdm-cluster
NAMESPACE ?= fleetdm
CHART_PATH ?= ./helm-chart
RELEASE_NAME ?= fleetdm

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

cluster: ## Create local Kubernetes cluster (Kind)
	@echo "Creating Kind cluster: $(CLUSTER_NAME)"
	@if kind get clusters | grep -q "^$(CLUSTER_NAME)$$"; then \
		echo "Cluster $(CLUSTER_NAME) already exists"; \
	else \
		kind create cluster --name $(CLUSTER_NAME) --config=- <<EOF; \
apiVersion: kind.x-k8s.io/v1alpha4 \
kind: Cluster \
nodes: \
- role: control-plane \
  kubeadmConfigPatches: \
  - | \
    kind: InitConfiguration \
    nodeRegistration: \
      kubeletExtraArgs: \
        node-labels: "ingress-ready=true" \
  extraPortMappings: \
  - containerPort: 80 \
    hostPort: 80 \
    protocol: TCP \
  - containerPort: 443 \
    hostPort: 443 \
    protocol: TCP \
  - containerPort: 30080 \
    hostPort: 30080 \
    protocol: TCP \
EOF \
		echo "Waiting for cluster to be ready..."; \
		kubectl wait --for=condition=Ready nodes --all --timeout=300s; \
		echo "Installing NGINX Ingress Controller..."; \
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml; \
		kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=300s; \
		echo "Cluster $(CLUSTER_NAME) is ready!"; \
	fi

cluster-minikube: ## Create local Kubernetes cluster (Minikube)
	@echo "Creating Minikube cluster"
	@if minikube status >/dev/null 2>&1; then \
		echo "Minikube cluster already exists"; \
		minikube status; \
	else \
		minikube start --driver=docker --cpus=2 --memory=4096; \
		minikube addons enable ingress; \
		echo "Minikube cluster is ready!"; \
	fi

install: ## Install the Helm chart
	@echo "Installing FleetDM Helm chart..."
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) \
		--namespace $(NAMESPACE) \
		--wait \
		--timeout 10m \
		--set mysql.auth.rootPassword=fleetdm-root-password \
		--set mysql.auth.password=fleetdm-password \
		--set redis.auth.password=fleetdm-redis-password \
		--set fleetdm.config.mysql.password=fleetdm-password \
		--set fleetdm.config.redis.password=fleetdm-redis-password
	@echo "Installation complete!"
	@echo ""
	@echo "Access FleetDM UI:"
	@echo "  NodePort: http://localhost:30080"
	@echo "  Or use port-forward: kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME) 8080:8080"
	@echo ""
	@make status

uninstall: ## Remove all deployed resources
	@echo "Uninstalling FleetDM Helm chart..."
	@helm uninstall $(RELEASE_NAME) --namespace $(NAMESPACE) || true
	@echo "Waiting for resources to be cleaned up..."
	@sleep 10
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "Uninstall complete!"

status: ## Show status of deployed resources
	@echo "=== Cluster Status ==="
	@kubectl cluster-info --context kind-$(CLUSTER_NAME) 2>/dev/null || kubectl cluster-info
	@echo ""
	@echo "=== Namespace: $(NAMESPACE) ==="
	@kubectl get all -n $(NAMESPACE) || echo "Namespace $(NAMESPACE) not found"
	@echo ""
	@echo "=== FleetDM Pods ==="
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=fleetdm || echo "No FleetDM pods found"
	@echo ""
	@echo "=== MySQL Pods ==="
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=mysql || echo "No MySQL pods found"
	@echo ""
	@echo "=== Redis Pods ==="
	@kubectl get pods -n $(NAMESPACE) -l app.kubernetes.io/name=redis || echo "No Redis pods found"
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n $(NAMESPACE) || echo "No services found"
	@echo ""
	@echo "=== Database Preparation Job ==="
	@kubectl get jobs -n $(NAMESPACE) -l app.kubernetes.io/component=prepare-db || echo "No prepare-db job found"

verify: ## Verify FleetDM, MySQL, and Redis are operational
	@echo "=== Verifying FleetDM ==="
	@kubectl wait --for=condition=ready pod -n $(NAMESPACE) -l app.kubernetes.io/name=fleetdm --timeout=300s || (echo "FleetDM pod not ready" && exit 1)
	@echo "FleetDM pod is ready"
	@kubectl exec -n $(NAMESPACE) -l app.kubernetes.io/name=fleetdm -- fleet version || echo "Could not get FleetDM version"
	@echo ""
	@echo "=== Verifying MySQL ==="
	@kubectl wait --for=condition=ready pod -n $(NAMESPACE) -l app.kubernetes.io/name=mysql --timeout=300s || (echo "MySQL pod not ready" && exit 1)
	@echo "MySQL pod is ready"
	@kubectl exec -n $(NAMESPACE) -l app.kubernetes.io/name=mysql -- mysql --version || echo "Could not get MySQL version"
	@echo ""
	@echo "=== Verifying Redis ==="
	@kubectl wait --for=condition=ready pod -n $(NAMESPACE) -l app.kubernetes.io/name=redis --timeout=300s || (echo "Redis pod not ready" && exit 1)
	@echo "Redis pod is ready"
	@kubectl exec -n $(NAMESPACE) -l app.kubernetes.io/name=redis -- redis-cli --version || echo "Could not get Redis version"
	@echo ""
	@echo "=== Verifying Database Preparation ==="
	@kubectl get jobs -n $(NAMESPACE) -l app.kubernetes.io/component=prepare-db -o jsonpath='{.items[0].status.conditions[?(@.type=="Complete")].status}' | grep -q "True" && echo "Database preparation completed successfully" || echo "Database preparation job not found or not completed"
	@echo ""
	@echo "=== All components verified! ==="

clean: ## Clean up local cluster
	@echo "Deleting Kind cluster: $(CLUSTER_NAME)"
	@kind delete cluster --name $(CLUSTER_NAME) || echo "Cluster $(CLUSTER_NAME) not found"

clean-minikube: ## Clean up Minikube cluster
	@echo "Stopping Minikube cluster"
	@minikube stop || echo "Minikube not running"
	@minikube delete || echo "Minikube cluster not found"

logs: ## Show logs from FleetDM pods
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/name=fleetdm --tail=50 -f

logs-db-prepare: ## Show logs from database preparation job
	@kubectl logs -n $(NAMESPACE) -l app.kubernetes.io/component=prepare-db --tail=50

port-forward: ## Port forward FleetDM service to localhost:8080
	@echo "Port forwarding FleetDM service to localhost:8080"
	@kubectl port-forward -n $(NAMESPACE) svc/$(RELEASE_NAME) 8080:8080


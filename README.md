# FleetDM Kubernetes Deployment

This repository contains a Helm chart for deploying FleetDM (an open-source device management platform) to Kubernetes, along with MySQL and Redis dependencies.

## Overview

FleetDM is a powerful device management platform that uses osquery to manage and monitor devices. This Helm chart packages:

- **FleetDM Server**: The main FleetDM application
- **MySQL**: Database backend (standalone MySQL 8.0 deployment)
- **Redis**: Caching and session storage (standalone Redis 7 deployment)

## Prerequisites

Before you begin, ensure you have the following installed:

- **kubectl** (v1.24+)
- **Helm** (v3.8+)
- **Kind** (v0.17+) or **Minikube** (v1.28+)
- **Docker** (for running local clusters)
- **make** (for using the Makefile)

### Verify Prerequisites

```bash
kubectl version --client
helm version
kind version  # or minikube version
docker --version
make --version
```

## Quick Start

### 1. Create Local Kubernetes Cluster

Using Kind (recommended):
```bash
make cluster
```

Or using Minikube:
```bash
make cluster-minikube
```

This will:
- Create a local Kubernetes cluster
- Install NGINX Ingress Controller (for Kind)
- Configure necessary port mappings

### 2. Install FleetDM

```bash
make install
```

This will:
- Create the `fleetdm` namespace
- Install MySQL and Redis dependencies
- Deploy FleetDM server
- Automatically run `fleet prepare db` to initialize the database
- Expose FleetDM via NodePort on port 30080

### 3. Verify Installation

```bash
make verify
```

This checks that:
- FleetDM pods are running and ready
- MySQL is operational
- Redis is operational
- Database preparation completed successfully

### 4. Access FleetDM UI

**Option 1: NodePort (default)**
```bash
# Access at http://localhost:30080
open http://localhost:30080
```

**Option 2: Port Forward**
```bash
make port-forward
# Then access at http://localhost:8080
```

**Option 3: Ingress (if configured)**
```bash
# Add to /etc/hosts:
# 127.0.0.1 fleetdm.local

# Access at http://fleetdm.local
```

## Installation & Teardown Instructions

### Installation Steps

1. **Create the cluster:**
   ```bash
   make cluster
   ```

2. **Install FleetDM:**
   ```bash
   make install
   ```

3. **Wait for all pods to be ready:**
   ```bash
   kubectl get pods -n fleetdm -w
   ```

4. **Verify installation:**
   ```bash
   make verify
   ```

### Teardown Steps

1. **Uninstall FleetDM:**
   ```bash
   make uninstall
   ```

2. **Delete the cluster (optional):**
   ```bash
   make clean  # For Kind
   # or
   make clean-minikube  # For Minikube
   ```

## Verification Steps

### Manual Verification

1. **Check Pod Status:**
   ```bash
   make status
   ```

   Expected output:
   - FleetDM pod: `Running` and `Ready`
   - MySQL pod: `Running` and `Ready`
   - Redis pod: `Running` and `Ready`
   - Database preparation job: `Complete`

2. **Check FleetDM Health:**
   ```bash
   kubectl exec -n fleetdm -l app.kubernetes.io/name=fleetdm -- fleet version
   ```

3. **Check MySQL Connection:**
   ```bash
   kubectl exec -n fleetdm -l app.kubernetes.io/name=mysql -- mysql -u fleet -p'fleetdm-password' -e "SHOW DATABASES;"
   ```

4. **Check Redis Connection:**
   ```bash
   kubectl exec -n fleetdm -l app.kubernetes.io/name=redis -- redis-cli -a 'fleetdm-redis-password' PING
   ```

5. **Verify Database Preparation:**
   ```bash
   make logs-db-prepare
   ```

   Look for: `Database migrations completed successfully`

6. **Access FleetDM UI:**
   ```bash
   # Using NodePort
   curl http://localhost:30080/healthz
   
   # Should return: {"status":"ok"}
   ```

### Automated Verification

Run the automated verification script:
```bash
make verify
```

## Configuration

### Customizing Values

Edit `helm-chart/values.yaml` or override values during installation:

```bash
helm upgrade --install fleetdm ./helm-chart \
  --namespace fleetdm \
  --set fleetdm.replicaCount=2 \
  --set mysql.primary.resources.limits.memory=1Gi
```

### Key Configuration Options

- **FleetDM Image**: Change `fleetdm.image.repository` and `fleetdm.image.tag`
- **Replicas**: Adjust `fleetdm.replicaCount` for high availability
- **Service Type**: Change `fleetdm.service.type` (NodePort, LoadBalancer, ClusterIP)
- **Resource Limits**: Modify `fleetdm.resources` for CPU/memory limits
- **Ingress**: Enable and configure `fleetdm.ingress` for external access

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                    │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   FleetDM    │  │    MySQL     │  │    Redis     │  │
│  │   Server     │──│   Database   │  │    Cache     │  │
│  │              │  │              │  │              │  │
│  └──────┬───────┘  └──────────────┘  └──────────────┘  │
│         │                                               │
│         │ Service (NodePort: 30080)                     │
│         │                                               │
│  ┌──────▼──────────────────────────────────────────┐   │
│  │           Ingress Controller (NGINX)            │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Agent Connectivity

FleetDM agents can connect to the server using:

1. **NodePort Service**: Agents connect to `<node-ip>:30080`
2. **Ingress**: If configured, agents can use the ingress hostname
3. **Port Forward**: For local testing, use port forwarding

To get the node IP:
```bash
kubectl get nodes -o wide
```

## Troubleshooting

### Pods Not Starting

1. **Check pod status:**
   ```bash
   kubectl get pods -n fleetdm
   kubectl describe pod <pod-name> -n fleetdm
   ```

2. **Check logs:**
   ```bash
   make logs
   ```

3. **Check events:**
   ```bash
   kubectl get events -n fleetdm --sort-by='.lastTimestamp'
   ```

### Database Connection Issues

1. **Verify MySQL is ready:**
   ```bash
   kubectl exec -n fleetdm -l app.kubernetes.io/name=mysql -- mysqladmin ping -u root -p'fleetdm-root-password'
   ```

2. **Check FleetDM logs for connection errors:**
   ```bash
   kubectl logs -n fleetdm -l app.kubernetes.io/name=fleetdm | grep -i mysql
   ```

### Database Preparation Failed

1. **Check job logs:**
   ```bash
   make logs-db-prepare
   ```

2. **Re-run database preparation:**
   ```bash
   kubectl delete job -n fleetdm -l app.kubernetes.io/component=prepare-db
   helm upgrade fleetdm ./helm-chart --namespace fleetdm
   ```

### Cannot Access FleetDM UI

1. **Verify service is running:**
   ```bash
   kubectl get svc -n fleetdm
   ```

2. **Check port forwarding:**
   ```bash
   make port-forward
   ```

3. **Verify NodePort:**
   ```bash
   kubectl get svc fleetdm -n fleetdm -o jsonpath='{.spec.ports[0].nodePort}'
   ```

## CI/CD Pipeline

This repository includes a GitHub Actions workflow (`.github/workflows/release.yml`) that:

- Lints the Helm chart
- Packages the chart
- Creates GitHub releases with chart artifacts
- Optionally publishes to a Helm repository

See the [CI/CD section](#cicd-pipeline) for more details.

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make cluster` | Create Kind cluster |
| `make cluster-minikube` | Create Minikube cluster |
| `make install` | Install Helm chart |
| `make uninstall` | Remove all deployed resources |
| `make status` | Show status of deployed resources |
| `make verify` | Verify all components are operational |
| `make clean` | Delete Kind cluster |
| `make clean-minikube` | Delete Minikube cluster |
| `make logs` | Show FleetDM logs |
| `make logs-db-prepare` | Show database preparation logs |
| `make port-forward` | Port forward FleetDM service |

## Security Considerations

⚠️ **Important**: This setup uses default passwords for demonstration. In production:

1. **Use Kubernetes Secrets** for sensitive data (already implemented)
2. **Set explicit passwords** in values.yaml or via `--set` flags to prevent regeneration
3. **Enable TLS** for FleetDM server
4. **Use strong passwords** for MySQL and Redis
5. **Enable network policies** to restrict pod-to-pod communication
6. **Use RBAC** to limit service account permissions
7. **Enable Pod Security Standards** or Pod Security Policies

### Password Management

**For Production Deployments:**

Always set explicit passwords to prevent regeneration on upgrades:

```bash
helm install fleetdm ./helm-chart \
  --namespace fleetdm \
  --set mysql.auth.rootPassword=<strong-password> \
  --set mysql.auth.password=<strong-password> \
  --set redis.auth.password=<strong-redis-password> \
  --set fleetdm.config.mysql.password=<strong-password> \
  --set fleetdm.config.redis.password=<strong-redis-password> \
  --set fleetdm.config.auth.jwt_key=<strong-jwt-key> \
  --set fleetdm.config.osquery.enroll_secret=<strong-enroll-secret>
```

**Note:** The Helm chart will preserve existing secrets on upgrades if they already exist in the cluster.

## Production Recommendations

1. **High Availability:**
   - Set `fleetdm.replicaCount: 3`
   - Use MySQL with replication
   - Use Redis Sentinel or Cluster mode

2. **Persistence:**
   - Ensure MySQL and Redis have persistent volumes
   - Configure backup strategies

3. **Monitoring:**
   - Add Prometheus metrics
   - Set up alerting
   - Monitor resource usage

4. **Security:**
   - Enable TLS/SSL
   - Use external secrets management
   - Implement network policies
   - Regular security updates

## License

This Helm chart is provided as-is for demonstration purposes.

## References

- [FleetDM Documentation](https://fleetdm.com/docs)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)


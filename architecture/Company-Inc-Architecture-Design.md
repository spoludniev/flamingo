# Company Inc. - Cloud Infrastructure Architecture Design Document

**Version:** 1.0  
**Date:** 2024  
**Author:** Infrastructure Team  
**Status:** Draft

---

## Executive Summary

This document outlines the cloud infrastructure architecture for Company Inc., a startup developing a web application with a Python/Flask backend, React frontend, and MongoDB database. The architecture is designed to be robust, scalable, secure, and cost-effective while supporting rapid growth from hundreds to millions of users.

**Recommended Cloud Provider:** **Amazon Web Services (AWS)**

AWS is selected for its mature managed Kubernetes (EKS) service, extensive service ecosystem, excellent MongoDB Atlas integration, comprehensive security features, and robust CI/CD tooling. AWS provides the flexibility and scalability needed for rapid growth from startup to enterprise scale.

---

## 1. Cloud Environment Structure

### 1.1 Multi-Account Strategy (AWS)

Company Inc. will use a **three-account structure** following AWS best practices via AWS Organizations:

1. **Development Account** (`company-inc-dev`)
   - Purpose: Development and testing environments
   - Billing: Consolidated billing under master payer account
   - Access: Full developer access with relaxed security policies
   - IAM: Developer-friendly policies with broad permissions

2. **Staging Account** (`company-inc-staging`)
   - Purpose: Pre-production environment mirroring production
   - Billing: Consolidated billing under master payer account
   - Access: Limited to DevOps and QA teams
   - IAM: Restricted policies similar to production

3. **Production Account** (`company-inc-prod`)
   - Purpose: Production workloads only
   - Billing: Consolidated billing with budget alerts and cost allocation tags
   - Access: Highly restricted, requires approval workflow
   - IAM: Least privilege access with MFA requirements

**AWS Organizations Structure:**
- Master Payer Account (billing consolidation)
- Organizational Units (OUs) for grouping accounts
- Service Control Policies (SCPs) for account-level guardrails
- Cost allocation tags for detailed cost tracking

### 1.2 Justification

**Isolation Benefits:**
- **Security:** Prevents accidental cross-environment access through account boundaries
- **Billing:** Clear cost attribution per environment with consolidated billing
- **Compliance:** Easier audit trails and regulatory compliance with account-level isolation
- **Blast Radius:** Limits impact of misconfigurations and security incidents
- **IAM Boundaries:** Account-level IAM provides stronger isolation than project-level permissions

---

## 2. Network Design

### 2.1 VPC Architecture

Each project will have its own VPC with the following structure:

**Production VPC:**
- **Region:** Multi-region (us-east-1 primary, us-west-2 secondary)
- **CIDR:** `10.0.0.0/16` (production), `10.1.0.0/16` (staging), `10.2.0.0/16` (dev)

**Subnet Design:**
- **Public Subnets** (`10.0.1.0/24`, `10.0.2.0/24` per AZ)
  - Purpose: Load balancers, NAT gateways, bastion hosts
  - Internet Gateway: Enabled
  - Route: `0.0.0.0/0` → Internet Gateway

- **Private Subnets** (`10.0.10.0/24`, `10.0.11.0/24` per AZ)
  - Purpose: Application pods, worker nodes
  - Internet Gateway: Disabled
  - Route: `0.0.0.0/0` → NAT Gateway

- **Database Subnets** (`10.0.20.0/24`, `10.0.21.0/24` per AZ)
  - Purpose: Database instances (if self-managed)
  - Internet Gateway: Disabled
  - Route: Local only (no internet access)

**Availability Zones:** Minimum 2 AZs per region for high availability

### 2.2 Network Security

**Security Groups (AWS):**

1. **Application Load Balancer Security Group:**
   - Ingress: `TCP:80,443` from `0.0.0.0/0` (internet)
   - Egress: `TCP:8080` to application security group
   - Attached to: Application Load Balancer

2. **Application Security Group:**
   - Ingress: `TCP:8080` from ALB security group
   - Egress: `TCP:27017` to database security group, `TCP:443` to internet (for external APIs)
   - Attached to: EKS worker nodes and pods

3. **Database Security Group:**
   - Ingress: `TCP:27017` from application security group only
   - Egress: None (no outbound access needed)
   - Attached to: MongoDB Atlas VPC endpoints

4. **Bastion Host Security Group:**
   - Ingress: `TCP:22` from approved IP ranges (office/VPN) or AWS VPN endpoint
   - Egress: `TCP:22` to application security group
   - Attached to: EC2 bastion instances

5. **Default Deny:**
   - Security groups default to deny all
   - Network ACLs provide additional subnet-level filtering
   - Explicit allow rules only for required traffic

**Network Policies (Kubernetes):**
- Implement namespace-level network policies using Calico or native Kubernetes Network Policies
- Restrict pod-to-pod communication to required services only
- Use service mesh (Istio or AWS App Mesh) for advanced traffic management and mTLS

**VPC Endpoints:**
- **Interface Endpoints:** For AWS services (ECR, Secrets Manager, CloudWatch Logs)
- **Gateway Endpoints:** For S3 and DynamoDB (no additional cost)
- Enables private connectivity to AWS services without internet routing
- Reduces data transfer costs and improves security

---

## 3. Compute Platform

### 3.1 Managed Kubernetes (EKS)

**Cluster Configuration:**
- **Type:** EKS cluster with managed node groups
- **Version:** Latest stable (1.28+)
- **Update Strategy:** Managed node group updates with rolling replacement
- **Network:** VPC CNI plugin (assigns VPC IPs to pods)
- **Control Plane:** AWS managed (multi-AZ by default)
- **Region:** Multi-region deployment (us-east-1 primary, us-west-2 secondary)

**Node Groups:**

1. **General Purpose Node Group:**
   - **Instance Type:** `t3.large` (2 vCPU, 8GB RAM) initially, scale to `m5.xlarge` (4 vCPU, 16GB RAM) as needed
   - **Min Nodes:** 2 per AZ (6 total minimum)
   - **Max Nodes:** 50 per AZ (150 total maximum)
   - **Purpose:** Application workloads (backend, frontend)
   - **Auto-scaling:** Cluster Autoscaler enabled
   - **Spot Instances:** 20% of nodes using Spot Instances for cost optimization
   - **AMI:** Amazon EKS Optimized AMI
   - **Subnets:** Private subnets across 3 AZs

2. **Database Connection Pool Node Group (Optional):**
   - **Instance Type:** `t3.medium` (2 vCPU, 4GB RAM)
   - **Min Nodes:** 1 per AZ (3 total)
   - **Max Nodes:** 10 per AZ (30 total)
   - **Purpose:** Database connection poolers, caching services (Redis, connection poolers)

### 3.2 Scaling Strategy

**Horizontal Pod Autoscaling (HPA):**
- **Metrics:** CPU (70% target), Memory (80% target), Custom metrics (request rate)
- **Min Replicas:** 3 (for high availability)
- **Max Replicas:** 50 per service
- **Scale-down:** Conservative (5-minute cooldown)

**Vertical Pod Autoscaling (VPA):**
- Enabled for recommendation mode initially
- Transition to auto mode after 2 weeks of observation

**Cluster Autoscaling:**
- AWS Cluster Autoscaler enabled
- Scale-down delay: 10 minutes (aggressive scale-down)
- Scale-up: Immediate for pending pods
- Scale-down: Only after 10 minutes of low utilization
- Pod disruption budgets respected during scale-down

**Node Group Management:**
- Managed node groups for automatic updates and patching
- Launch templates for consistent node configuration
- User data scripts for node initialization
- Max nodes: 200 total across all node groups

### 3.3 Containerization Strategy

**Image Building:**
- **Registry:** Amazon Elastic Container Registry (ECR)
- **Build Tool:** AWS CodeBuild or GitHub Actions
- **Base Images:** 
  - Backend: `python:3.11-slim` (official Python image)
  - Frontend: `nginx:alpine` (for serving React SPA)
- **Multi-stage Builds:** Enabled to minimize image size
- **Image Scanning:** Amazon ECR image scanning for vulnerability detection
- **Image Lifecycle:** ECR lifecycle policies for automatic cleanup of old images

**CI/CD Pipeline:**
```
GitHub → CodeBuild/CodePipeline → Build Image → 
Scan Image (ECR) → Push to ECR → Deploy to EKS
```

**AWS CodePipeline Stages:**
1. **Source:** GitHub webhook triggers pipeline
2. **Build:** CodeBuild compiles and builds Docker images
3. **Test:** Run automated tests
4. **Deploy:** Update EKS deployment using kubectl or Helm

**Deployment Strategy:**
- **Development:** Rolling updates (immediate)
- **Staging:** Blue-green deployments
- **Production:** Canary deployments (10% → 50% → 100%)

**Image Tagging:**
- `latest` → Development
- `staging-<commit-sha>` → Staging
- `v<semver>` → Production (immutable tags)

**Resource Allocation:**
- **Backend Pods:**
  - Requests: `500m CPU, 512Mi memory`
  - Limits: `2000m CPU, 2Gi memory`
- **Frontend Pods:**
  - Requests: `100m CPU, 128Mi memory`
  - Limits: `500m CPU, 512Mi memory`

---

## 4. Database

### 4.1 Managed MongoDB Service

**Recommendation: MongoDB Atlas on AWS**

**Justification:**
- **Fully Managed:** No operational overhead
- **Multi-Region:** Built-in replication and failover
- **Security:** Encryption at rest and in transit, VPC peering
- **Scaling:** Horizontal and vertical scaling without downtime
- **Backups:** Automated continuous backups
- **Cost:** Pay-as-you-grow model suitable for startups
- **AWS Integration:** Native AWS VPC peering and IAM integration

**Configuration:**
- **Tier:** M10 cluster (2GB RAM, 10GB storage) initially
- **Region:** `us-east-1` (primary), `us-west-2` (secondary)
- **Replication:** 3-node replica set (1 primary, 2 secondaries)
- **Storage:** 10GB initially, auto-scaling enabled
- **Network:** VPC peering with EKS VPC for private connectivity
- **Cloud Provider:** AWS (same as EKS cluster for low latency)

**Alternative:** Self-managed MongoDB on EKS (not recommended for startup)

### 4.2 Automated Backups

**MongoDB Atlas Backups:**
- **Snapshot Frequency:** Every 6 hours
- **Retention:** 2 days (48 hours)
- **Point-in-Time Recovery:** Enabled (24-hour window)
- **Backup Storage:** AWS S3 (same region)

**Additional Backup Strategy:**
- **Daily Exports:** Automated daily `mongodump` to S3
- **Retention:** 
  - Standard storage: 30 days for daily backups
  - Standard-IA (Infrequent Access): 90 days for weekly backups
  - Glacier: 1 year for monthly backups
- **Encryption:** All backups encrypted at rest using S3 server-side encryption (SSE-S3 or SSE-KMS)
- **Cross-Region Replication:** S3 cross-region replication for disaster recovery

**Backup Testing:**
- Monthly restore tests to verify backup integrity
- Documented recovery procedures (RTO: 1 hour, RPO: 6 hours)

### 4.3 High Availability

**Multi-AZ Deployment:**
- Primary region: `us-east-1` (3 AZs: us-east-1a, us-east-1b, us-east-1c)
- Secondary region: `us-west-2` (3 AZs) for disaster recovery
- Replica set members distributed across AZs
- MongoDB Atlas automatically distributes nodes across AZs for high availability

**Read Preferences:**
- **Primary Reads:** For consistency-critical operations
- **Secondary Reads:** For analytics and reporting workloads
- **Read Preference:** `nearest` for low latency

**Connection String:**
- Use MongoDB Atlas connection string with replica set
- Application retry logic for transient failures
- Connection pooling: 100 connections per pod

### 4.4 Disaster Recovery Strategy

**RTO (Recovery Time Objective):** 1 hour  
**RPO (Recovery Point Objective):** 6 hours

**DR Plan:**

1. **Regional Failover:**
   - MongoDB Atlas: Automatic failover to secondary region
   - Application: Update connection strings via ConfigMap
   - DNS: Update CNAME to point to secondary region load balancer

2. **Data Recovery:**
   - Restore from latest snapshot (if needed)
   - Point-in-time recovery to specific timestamp
   - Validate data integrity before resuming traffic

3. **Testing:**
   - Quarterly DR drills
   - Document lessons learned
   - Update runbooks based on test results

**Backup Locations:**
- Primary: Same region S3 bucket (us-east-1)
- Secondary: Cross-region replication to us-west-2 (daily)
- Tertiary: S3 Glacier for long-term archival (weekly, 90-day retention)

---

## 5. Additional Considerations

### 5.1 Security

- **Secrets Management:** AWS Secrets Manager with automatic rotation
- **IAM:** Least privilege access, IAM roles for service accounts (IRSA) for EKS pods
- **Pod Security:** Pod Security Standards (restricted mode) or Pod Security Policies
- **Network Policies:** Kubernetes Network Policies (Calico) for micro-segmentation
- **WAF:** AWS WAF on Application Load Balancer for DDoS protection and web application security
- **TLS:** Certificates via AWS Certificate Manager (ACM) or Let's Encrypt (cert-manager)
- **Encryption:** 
  - EBS volumes encrypted at rest (KMS)
  - S3 buckets encrypted (SSE-S3 or SSE-KMS)
  - Secrets encrypted in Secrets Manager (KMS)
  - TLS in transit for all communications

### 5.2 Monitoring & Observability

- **Logging:** 
  - CloudWatch Logs for application and system logs
  - Fluent Bit daemonset for log aggregation
  - CloudWatch Logs Insights for querying
- **Metrics:** 
  - CloudWatch Container Insights for EKS metrics
  - Prometheus + Grafana (self-hosted on EKS or AWS Managed Prometheus)
  - CloudWatch custom metrics
- **APM:** 
  - AWS X-Ray for distributed tracing
  - OpenTelemetry for vendor-agnostic tracing
- **Alerting:** 
  - CloudWatch Alarms with SNS notifications
  - PagerDuty integration for critical alerts
  - EventBridge for event-driven automation

### 5.3 Cost Optimization

- **Reserved Instances:** 
  - EC2 Reserved Instances (1-year or 3-year terms) for predictable workloads
  - Savings Plans for flexible compute usage
- **Spot Instances:** 20% of cluster capacity using Spot Instances
- **Right-sizing:** 
  - Regular review of resource requests/limits
  - AWS Cost Explorer for cost analysis
  - Compute Optimizer recommendations
- **Idle Resource Cleanup:** 
  - Automated cleanup of unused resources
  - S3 lifecycle policies for backup retention
- **Budget Alerts:** 
  - AWS Budgets with alerts at 50%, 80%, 100% of monthly budget
  - Cost allocation tags for detailed tracking
- **Data Transfer:** 
  - VPC endpoints to reduce data transfer costs
  - CloudFront for static content delivery

---

## 6. Migration Path

**Phase 1 (Weeks 1-2):** Set up AWS accounts via Organizations, VPCs, and EKS clusters  
**Phase 2 (Weeks 3-4):** Deploy application to staging environment  
**Phase 3 (Weeks 5-6):** Set up MongoDB Atlas on AWS and migrate data  
**Phase 4 (Weeks 7-8):** Production deployment with canary rollout  
**Phase 5 (Ongoing):** Monitor, optimize, and scale

---

## Conclusion

This architecture provides Company Inc. with a scalable, secure, and cost-effective foundation that can grow from hundreds to millions of users. The use of managed services (EKS, MongoDB Atlas) minimizes operational overhead while maintaining flexibility for future requirements.

**Key Strengths:**
- ✅ Multi-project isolation for security and billing
- ✅ Highly available multi-AZ deployment
- ✅ Automated scaling (horizontal and vertical)
- ✅ Comprehensive backup and disaster recovery
- ✅ Cost-optimized with spot instances and right-sizing
- ✅ CI/CD ready with containerized deployments

---

**Document Control:**
- **Next Review:** Quarterly or upon significant architecture changes
- **Approvers:** CTO, DevOps Lead, Security Lead


# Creating the Architecture Diagram in draw.io

## Steps to Create the Diagram

1. **Open draw.io**
   - Go to https://app.diagrams.net/ or use the desktop app
   - Create a new diagram

2. **Set Canvas Size**
   - File → Page Setup
   - Set to A4 or Letter size
   - Landscape orientation

3. **Create the Diagram Structure**

### Main Components to Add:

#### 1. AWS Organization Box
- Draw a large rectangle labeled "AWS Organization"
- Inside, create three boxes: "Production Account", "Staging Account", "Development Account"
- Add note about AWS Organizations master payer account

#### 2. Production VPC
- Inside Production Account, draw a VPC box
- Add three subnet sections:
  - **Public Subnets**: Application Load Balancer (ALB), NAT Gateway, Bastion Host (EC2)
  - **Private Subnets**: EKS Cluster with managed node groups
  - **Database Subnets**: VPC Peering connection to MongoDB Atlas

#### 3. EKS Cluster Details
- Draw EKS Regional Cluster box
- Add three managed node groups (one per AZ)
- Inside each node group, add:
  - Flask Backend Pods (with HPA indicator)
  - React Frontend Pods (with HPA indicator)
- Label instance types: t3.large or m5.xlarge

#### 4. MongoDB Atlas
- Draw MongoDB Atlas section (on AWS)
- Show Primary Region (us-east-1) with 3-node replica set
- Show Secondary Region (us-west-2) for DR
- Add backup strategy annotations (S3, Glacier)

#### 5. CI/CD Pipeline
- Draw flow: GitHub → CodeBuild/CodePipeline → ECR → EKS
- Use arrows to show the flow
- Add AWS CodePipeline stages

#### 6. Security & Monitoring
- Add boxes for: AWS Secrets Manager, AWS WAF (on ALB), Prometheus/Grafana, CloudWatch Logs
- Add VPC Endpoints for private AWS service access

#### 7. User Access
- Show End Users → Application Load Balancer → Application
- Show Developers → Bastion (EC2) → EKS

### Color Scheme (AWS Colors)
- Load Balancer/ALB: #FF9900 (Orange)
- EKS/Compute: #232F3E (Dark Blue)
- MongoDB: #13a52c (Green)
- CodeBuild: #FF9900 (Orange)
- Secrets Manager: #232F3E (Dark Blue)
- S3: #569A31 (Green)

### Connectors
- Use arrows to show:
  - Data flow (solid lines)
  - Network connections (dashed lines)
  - CI/CD pipeline (colored arrows)

### Labels
- Add labels for:
  - Subnet CIDRs (10.0.0.0/16, etc.)
  - Instance types (t3.large, m5.xlarge)
  - Scaling ranges (e.g., "3-50 replicas")
  - AWS Regions (us-east-1, us-west-2) and AZs
  - Security Group names
  - IAM roles (IRSA for pods)

## Export Options

1. **For PDF**: File → Export as → PDF
2. **For PNG**: File → Export as → PNG (high resolution)
3. **For SVG**: File → Export as → SVG (vector format)

## Alternative: Use the Mermaid Diagram

The `architecture-diagram.mmd` file contains a Mermaid diagram that can be:
- Rendered in GitHub (automatically)
- Rendered in VS Code with Mermaid extension
- Converted to images using mermaid-cli

```bash
# Install mermaid-cli
npm install -g @mermaid-js/mermaid-cli

# Generate PNG
mmdc -i architecture-diagram.mmd -o architecture-diagram.png

# Generate SVG
mmdc -i architecture-diagram.mmd -o architecture-diagram.svg
```


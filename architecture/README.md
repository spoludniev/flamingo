# Architecture Documentation

This directory contains the architectural design document for Company Inc.

## Files

- `Company-Inc-Architecture-Design.md` - Complete architectural design document (1-2 pages)
- `architecture-diagram.drawio` - High-level architecture diagram (draw.io format)
- `architecture-diagram.png` - Exported PNG version of the diagram

## High-Level Architecture Diagram

The architecture diagram illustrates:

1. **Multi-Project Structure:** Dev, Staging, and Production projects
2. **Network Architecture:** VPC with public/private/database subnets
3. **Compute Layer:** GKE cluster with node pools and auto-scaling
4. **Application Layer:** Containerized backend (Flask) and frontend (React)
5. **Data Layer:** MongoDB Atlas with multi-region replication
6. **Security:** Firewall rules, network policies, and secrets management
7. **CI/CD:** Cloud Build pipeline for automated deployments

## Viewing the Diagram

1. **Online:** Import `architecture-diagram.drawio` into [draw.io](https://app.diagrams.net/)
2. **Local:** Open with draw.io desktop application
3. **PNG:** View `architecture-diagram.png` directly

## Converting to PDF

To convert the markdown document to PDF:

```bash
# Using pandoc
pandoc Company-Inc-Architecture-Design.md -o Company-Inc-Architecture-Design.pdf

# Using markdown-pdf (npm)
npx markdown-pdf Company-Inc-Architecture-Design.md
```


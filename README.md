# Grafana-Prometheus Azure DevOps Project

This project automates the setup and deployment of Grafana and Prometheus using Ansible and Docker, integrated with Azure DevOps pipelines. The setup includes configuring Node Exporter on target hosts, setting up SSL certificates and configuring Azure DNS zones, and deploying containers using Docker Compose.

![Azure DevOps](https://github.com/user-attachments/assets/dc1f2019-25e8-4c91-8c26-6800e7d975d3)

## Table of Contents
- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
- [Pipeline Configuration](#pipeline-configuration)
- [Docker Compose Configuration](#docker-compose-configuration)
- [Prometheus Configuration](#prometheus-configuration)
- [Jenkins Configuration](#jenkins-configuration)
- [Ansible Playbook](#ansible-playbook)
- [Clean Script](#clean-script)
- [Credits](#credits)
  
---

## Project Overview

This Azure DevOps setup enables:
- **Monitoring:** Grafana for visualization and Prometheus for metrics collection.
- **Metrics Collection:** Node Exporter collects system metrics from servers.
- **CI/CD Pipeline:** Azure Pipeline automates the build and release pipelines using webhooks on code pushes.
- **Self-Hosted Agents:** Configured Ansible and Docker agents on two nodes
- **Azure DNS Zone:** Configured Azure DNS Zone for the hosting of my own domain
- **NSG Rules:** Configured Network Security Group for inbound port access in Azure Firewall
- **Containerized Services:** All components run inside Docker containers for easy management

---

## Prerequisites

Before starting, ensure the following tools are installed:

- **Docker** (on the Docker agent node, which acts as the Docker server)
- **Docker Compose** (on the Docker agent node, which acts as the Docker server)
- **Agents for Self-Hosted** (on both agent nodes, which acts as the Self-Hosted Agents)
- **Ansible** (on the Ansible agent node, which acts as the Ansible control node)
  
---

## Setup Instructions

### Docker Compose Configuration

Create a `docker-compose.yml` file in the project directory with the following content:

```yaml
# Author: Kabbil GI
# Date: 19-12-2024

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    user: "472:472"
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=<PASSWD>
    volumes:
      - ./grafana:/var/lib/grafana
    restart: unless-stopped

networks:
  default:
    driver: bridge
```

## Prometheus Configuration

Create a Prometheus configuration file at prometheus/prometheus.yml with the following content, and modify localhost to the IP address of your Grafana server:

```yaml
# Author: Kabbil GI
# Date: 18-01-2025

global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets:
        - '74.225.214.17:9100'
        - '52.172.206.183:9100'
        - '20.204.175.3:9100'
```

## Azure Pipeline Configuration

Set up a Azure Pipeline job to trigger on push events from your Azure repo using webhooks. This ensures that any code modifications pushed to the repository automatically trigger the build process.

Job Steps:
1. Checkout Code: Pull the latest code from the Azure repo.
2. Run Ansible Playbooks: **BUILD-1** Configure the job to run the Ansible playbooks for Node Exporter and Grafana-Prometheus setup.
3. Save images and build artifacts: **BUILD-2** Configure the job to save images as tar files and publish the build artifacts.
4. 

















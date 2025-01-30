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

## pipeline-configuration

### This is the Azure DevOps build and release pipeline configuration

Create a azure-pipelines.yml file in the project directory with the following content:

```yaml
trigger:
  - main

jobs:
  - job: Build1
    displayName: 'Grafana-Prometheus Setup'
    pool:
      name: ansible_agent
    steps:
    - script: ansible-playbook /home/ansible/Grafana-Prometheus/grafana-prometheus.yml
      displayName: 'Run Ansible Playbook for Grafana-Prometheus Setup'

  - job: Build2
    displayName: 'Docker Image Build'
    dependsOn: Build1
    pool:
      name: docker_agent
    steps:
    - script: |
        # Build Docker images
        # docker-compose -f /home/devops/docker-compose.yml up --no-start
        
        # Save new Docker images as tar files
        docker save -o prometheus.tar prom/prometheus:latest
        docker save -o grafana.tar grafana/grafana:latest
        
        # Move tar files to a separate directory
        mkdir -p $(Pipeline.Workspace)/docker-images
        mv prometheus.tar $(Pipeline.Workspace)/docker-images/
        mv grafana.tar $(Pipeline.Workspace)/docker-images/
      displayName: 'Build Docker Images and Save as Tar Files'

    - task: PublishBuildArtifacts@1
      inputs:
        pathtoPublish: $(Pipeline.Workspace)/docker-images
        artifactName: docker-images
        publishLocation: 'Container'
      displayName: 'Publish Docker Images as Artifacts'
```

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
4. Push images to docker hub: Once artifacts are built Release pipeline gets triggered.Once approved **APPROVAL_GATE** it will download the 
   artifacts and push images to docker hub repository.
5. Clean environment: Once approved **APPROVAL_GATE** it will stop the containers and prune the docker images.

---

## Ansible Playbook

```yaml
# Author: Kabbil GI
# Date: 18-01-2025
---
- name: Node Exporter config
  hosts: all
  gather_facts: no
  ignore_unreachable: yes
  tasks:
    - name: Running Node Exporter Configuration
      get_url:
        url: https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz
        dest: /root/node_exporter-1.8.2.linux-amd64.tar.gz

    - name: Extracting the downloaded Node Exporter
      unarchive:
        src: /root/node_exporter-1.8.2.linux-amd64.tar.gz 
        dest: /root/
        remote_src: yes

    - name: Kill existing Node Exporter processes 
      shell: pkill -f node_exporter 
      ignore_errors: yes
    
    - name: Run Node Exporter
      shell: nohup ./node_exporter &
      args:
        chdir: /root/node_exporter-1.8.2.linux-amd64

- name: grafana-prometheus playbook config
  hosts: docker
  become_user: devops
  tasks:
    - name: Copy Docker Compose file
      copy:
        src: /home/ansible/Grafana-Prometheus/docker-compose.yml
        dest: /home/devops/docker-compose.yml

    - name: Ensure Prometheus configuration directory exists
      file:
        path: /home/devops/prometheus
        state: directory

    - name: Copy Prometheus configuration file
      copy:
        src: /home/ansible/Grafana-Prometheus/prometheus/prometheus.yml
        dest: /home/devops/prometheus/prometheus.yml

    - name: Ensure Grafana data directory exists with 472 permissions
      become_user: root
      file:
        path: /home/devops/grafana
        state: directory
        owner: 472
        group: 472
    
    - name: Copy clean.sh file
      copy: 
        src: /home/ansible/Grafana-Prometheus/clean.sh
        dest: /home/devops/clean.sh
        mode: 0755
      
    - name: Start the Grafana and Prometheus containers 
      shell: |
        docker-compose down
        docker image prune -a -f
        docker-compose up -d
      args:
        chdir: /home/devops
    
    - name: Apply the tags to the containers
      shell: |
        docker tag prom/prometheus kabbilkarthi/azure-devops:prometheus
        docker tag grafana/grafana kabbilkarthi/azure-devops:grafana
      args:
        chdir: /home/devops
```

## Clean Script 

```bash
#!/bin/bash

# Remove all stopped docker images and containers

docker image prune -a -f
docker container prune -f
```

## Credits

### Author: Kabbil GI
### Date: 18-01-2025
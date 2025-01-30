Grafana-Prometheus DevOps Project
This project sets up a Grafana and Prometheus monitoring stack running inside Docker containers using docker-compose. It also includes Node Exporter for system metrics collection and automates the build and deployment processes using Azure DevOps.

Table of Contents
Project Overview

Prerequisites

Setup Instructions

Pipeline Configuration

Docker Compose Configuration

Ansible Playbook

Clean Script

Credits

Project Overview
This DevOps setup enables:

Monitoring: Grafana for visualization and Prometheus for metrics collection.

Metrics Collection: Node Exporter collects system metrics from servers.

CI/CD Pipeline: Azure DevOps automates the deployment using the provided pipeline configuration.

Containerized Services: All components run inside Docker containers for easy management.

Prerequisites
Before starting, ensure the following:

Ansible Servers: Pre-configured with the required packages.

Docker Servers: Pre-configured with the required packages and SSL certificates.

Self-hosted Azure DevOps Agents: Running on our Azure virtual machines.

SSL Certificates: Configured on the Docker server using Azure DNS Zone with an A record pointing to the Docker server.

Setup Instructions
Clone the Repository:

bash
git clone https://github.com/your-username/your-repo.git
cd your-repo
Ensure Prerequisites are Met: Confirm that Ansible and Docker servers are pre-configured with the required packages, and SSL certificates are configured using Azure DNS.

Run the Ansible Playbook:

bash
ansible-playbook grafana-prometheus.yml
Set Up Azure DevOps Pipeline: Import the provided pipeline configuration into your Azure DevOps project. Ensure the agent pools (ansible_agent and docker_agent) are correctly configured and accessible.

Pipeline Configuration
Here's the Azure DevOps pipeline configuration:

yaml
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
        # Save new Docker images as tar files
        docker save -o prometheus.tar prom/prometheus:latest
        docker save -o grafana.tar grafana/grafana:latest
        
        # Move tar files to a separate directory
        mkdir -p $(Pipeline.Workspace)/docker-images
        mv prometheus.tar $(Pipeline.Workspace)/docker-images/
        mv grafana.tar $(Pipeline.Workspace)/docker-images/
      displayName: 'Save Images as Tar Files'

    - task: PublishBuildArtifacts@1
      inputs:
        pathtoPublish: $(Pipeline.Workspace)/docker-images
        artifactName: docker-images
        publishLocation: 'Container'
      displayName: 'Publish Docker Images as Artifacts'
Docker Compose Configuration
Create a docker-compose.yml file in the project directory with the following content:

yaml
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
      - GF_SECURITY_ADMIN_PASSWORD=kabbil
    volumes:
      - ./grafana:/var/lib/grafana
    restart: unless-stopped

networks:
  default:
    driver: bridge
Ansible Playbook
Create a grafana-prometheus.yml file with the following content:

yaml
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
Clean Script
Create a clean.sh file with the following content:

bash
#!/bin/bash

# Remove all stopped docker images and containers

docker image prune -a -f
docker container prune -f
Credits
Author: Kabbil GI

Date: 18-01-2025
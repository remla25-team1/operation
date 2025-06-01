# Deployment Documentation 📦

## 1. System Overview 🚀

This document describes our final Kubernetes deployment of the tweet sentiment analysis system (A3). It covers:

- **Cluster Topology**: Vagrant‐provisioned VMs and node roles  
- **Deployed Resources**: All Kubernetes objects and how they relate  
- **Data Flow**: Request routing, metrics collection, and alerting  
- **Visualizations**: Mermaid diagrams embedded for clarity  

After reading, a new team member should understand how to bring up, inspect, and extend the system.

---

### 1.1 Cluster Topology 🖥️

- **ctrl (192.168.56.100)**  
  - Kubernetes control‐plane (API server, scheduler, controller‐manager)  
  - Hosts the NGINX Ingress Controller Pod (namespace `ingress-nginx`)  
- **k8s-node-1 (192.168.56.101)**  *(labeled `node-role=model`)*  
  - Schedules all `model-service` Pods  
- **k8s-node-2 (192.168.56.102)**  *(labeled `node-role=app`)*  
  - Schedules all `app` Pods  
- **Shared Folder**: All VMs mount `/mnt/shared` via VirtualBox  

Networking:  
- Host‐only network 192.168.56.0/24  
- `/etc/hosts` on the host maps `app.local` → `192.168.56.90` (Ingress LoadBalancer)

---

## 2. Deployed Resources 🏗️

Below is a concise inventory of every Kubernetes object, grouped by category. No YAML details—just concepts and relations.

### 2.1 Namespaces

- `default`:  
  - Hosts `app`, `model-service`, ConfigMaps, Secrets, Ingress  
- `ingress-nginx`:  
  - NGINX Ingress Controller Deployment & Service  
- `monitoring`:  
  - Prometheus, Grafana, Alertmanager, ServiceMonitors, Rules

---

### 2.2 Deployments & Pods

- **app (Deployment)**  
  - **Replicas**: 3 ✔️  
  - **NodeSelector**: `node-role=app`  
  - **Function**: Serves UI & forwards inference requests to `model-service`  
  - **Metrics**: Exposes `/metrics` on port 8080

- **model-service (Deployment)**  
  - **Replicas**: 2 ✔️  
  - **NodeSelector**: `node-role=model`  
  - **Function**: Preprocesses (via `lib-ml`), runs sentiment model, returns JSON  
  - **Metrics**: Exposes `/metrics` on port 5000

- **ingress-nginx-controller (Deployment)**  
  - **Namespace**: `ingress-nginx`  
  - **Function**: Receives external HTTP(S) traffic, forwards to `app` Service

- **prometheus (Deployment)**  
  - **Namespace**: `monitoring`  
  - **Function**: Scrapes metrics from application Pods & cluster components  

- **grafana (Deployment)**  
  - **Namespace**: `monitoring`  
  - **Function**: Visualizes metrics with custom dashboards  

- **alertmanager (Deployment)**  
  - **Namespace**: `monitoring`  
  - **Function**: Sends email alerts when Prometheus rules trigger  

---

### 2.3 Services 🌐

- **Service `app`**  
  - **Type**: NodePort (external access on each node)  
  - **Port**: 8080 → NodePort 32045  
  - **Selector**: `app=app` → balances among 3 `app` Pods  

- **Service `model-service`**  
  - **Type**: ClusterIP (internal)  
  - **Port**: 5000  
  - **Selector**: `app=model-service` → routes to 2 `model-service` Pods  

- **Service `ingress-nginx-controller`**  
  - **Namespace**: `ingress-nginx`  
  - **Type**: LoadBalancer → External IP 192.168.56.90  
  - **Ports**: 80, 443 → routes to Ingress Pods  

- **Service `prometheus`**  
  - **Namespace**: `monitoring`  
  - **Type**: ClusterIP 9090 → Prometheus UI/API  

- **Service `grafana`**  
  - **Namespace**: `monitoring`  
  - **Type**: ClusterIP 80 → Grafana UI (forward via `kubectl port-forward`)  

---

### 2.4 Ingress & Routing 🛣️

- **Ingress resource `app-ingress`** (namespace `default`)  
  - **Host**: `app.local`  
  - **Path `/`** → forwards to Service `app` (port 8080)  
  - **Annotation**: `nginx.ingress.kubernetes.io/rewrite-target: /`  

- **DNS / Hosts**:  
  - On host machine, add  
    ```
    192.168.56.90   app.local
    ```

---

### 2.5 ConfigMaps & Secrets 🔑

- **ConfigMap `application-config`** (namespace `default`)  
  - Provides environment variables to `app` Pods:  
    - `MODEL_SERVICE_HOST="model-service"`  
    - `MODEL_SERVICE_PORT="5000"`  
    - Any feature flags (e.g., `ENABLE_FEEDBACK="true"`)

- **Secret `ghcr-secret`** (namespace `default`)  
  - Docker registry credentials to pull images from `ghcr.io/remla25-team1`  

- **Secret `smtp-credentials`** (namespace `monitoring`)  
  - Contains base64-encoded SMTP username/password for Alertmanager email alerts  

---

### 2.6 Monitoring CRDs 📈

- **ServiceMonitor `app-servicemonitor`**  
  - **Selector**: `app=app`  
  - **Endpoint**: `/metrics` (port 8080), interval 15s  

- **ServiceMonitor `model-servicemonitor`**  
  - **Selector**: `app=model-service`  
  - **Endpoint**: `/metrics` (port 5000), interval 15s  

- **PrometheusRule `prometheusrule-app`**  
  - **Alert**: `HighRequestRate` → when `rate(sentiment_requests_total[1m]) > 15` for 2m  
  - Sends severity `warning`

- **AlertmanagerConfig `alertmanagerconfig-smtp`**  
  - **Route**: all alerts → `smtp-receiver`  
  - **Receiver**: `smtp-receiver` sends email using `smtp-credentials` to `dev-team@example.com`  

---

## 3. Data Flow & Dynamic Routing 🔄

Below is a sequence diagram illustrating how a tweet inference request moves through the system, where metrics are recorded, and where alerts may fire.

```mermaid
sequenceDiagram
  autonumber
  actor U as Browser (app.local)
  participant I as Ingress (192.168.56.90)
  participant S1 as Service “app”
  participant P1 as Pod “app” (3 replicas)
  participant S2 as Service “model-service”
  participant P2 as Pod “model-service” (2 replicas)
  participant PR as Prometheus
  participant GF as Grafana
  participant AM as Alertmanager

  U->>I: GET /predict?tweet="I love cats!"
  I->>S1: Forward to Service “app”
  S1->>P1: Route to one of 3 “app” Pods

  Note over P1:  
    • Increments Counter `sentiment_requests_total{}`  
    • Starts timer for Histogram `sentiment_response_time_seconds`  

  P1->>S2: POST /infer {"tweet":"I love cats!"}
  S2->>P2: Route to one of 2 “model-service” Pods

  Note over P2:  
    • Preprocess (lib-ml)  
    • Increments Counter `sentiment_inference_total{}`  
    • Records Histogram `sentiment_inference_latency_seconds`  

  P2-->>P1: Return JSON { "sentiment":"positive" }
  P1-->>U: Return final JSON + render UI

  Note over P1:  
    • Stops timer → record `sentiment_response_time_seconds`  
    • Increments Counter `sentiment_responses_total{sentiment="positive"}`  

  loop Every 15s
    PR-->P1: scrape `/metrics`
    PR-->P2: scrape `/metrics`
  end

  PR->>GF: Update dashboards
  alt rate(sentiment_requests_total[1m]) > 15 for 2m
    PR->>AM: Fire “HighRequestRate”  
    AM->>Dev: Send email alert 💌
  end
```
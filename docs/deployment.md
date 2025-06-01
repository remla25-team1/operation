# 📄 Deployment Documentation

## 📦 Helm Chart Overview

The deployment consists of multiple components defined in the Helm Chart:

```mermaid
graph TD
  A[operation/] --> B[templates/]
  B --> B1[_helpers.tpl]
  B --> B2[NOTES.txt]
  B --> B3[app-deployment.yaml]
  B --> B4[app-service.yaml]
  B --> B5[configMap.yaml]
  B --> B6[ingress.yaml]
  B --> B7[model-deployment.yaml]
  B --> B8[model-service.yaml]
  B --> B9[secret.yaml]
  B --> B10[servicemonitor.yaml]
```


## 🧩 Resources Overview

| File                    | Resource Type   | Description                                |
|-------------------------|-----------------|--------------------------------------------|
| `app-deployment.yaml`   | Deployment      | Deploys the main application container     |
| `app-service.yaml`      | Service         | Exposes the application to internal network|
| `model-deployment.yaml` | Deployment      | Deploys ML model(s)                         |
| `model-service.yaml`    | Service         | Exposes model to internal/external clients |
| `configMap.yaml`        | ConfigMap       | Configuration for the application           |
| `secret.yaml`           | Secret          | Manages sensitive credentials               |
| `ingress.yaml`          | Ingress         | Exposes services via HTTP                    |
| `servicemonitor.yaml`   | ServiceMonitor  | Prometheus monitoring configuration         |


## 🌐 Deployment Architecture

```mermaid
graph LR
  subgraph Frontend
    APP[app Deployment]
    APPSVC[app Service]
  end

  subgraph Backend
    MODEL[model-service Deployment]
    MODELSVC[model-service Service]
  end

  subgraph Ingress
    INGRESS[Ingress Controller]
  end

  USER[User]

  USER -->|HTTP Request| INGRESS
  INGRESS -->|Route to app Service| APPSVC
  APPSVC -->|API Calls| MODELSVC
  MODELSVC --> MODEL

  style APP fill:#9fdfbf,stroke:#333,stroke-width:2px
  style MODEL fill:#f9d4a6,stroke:#333,stroke-width:2px
  style INGRESS fill:#bbdefb,stroke:#333,stroke-width:2px
```

## 🔁 Request Handling Flow

1. User sends a request to the application via the Ingress controller (`app.local`).  
2. The Ingress (`192.168.56.90`) routes incoming requests based on host/path rules to the `app-service`.  
3. The `app-service` pods (3 replicas) handle frontend and API gateway logic:  
   - Increments counter `sentiment_requests_total{}`  
   - Starts timer for histogram `sentiment_response_time_seconds`  
   - Forwards sentiment analysis requests to the `model-service`.  
4. The `model-service` pods (2 replicas) perform ML inference:  
   - Preprocess input using ML library  
   - Increments counter `sentiment_inference_total{}`  
   - Records histogram `sentiment_inference_latency_seconds`  
   - Returns sentiment prediction JSON.  
5. The `app-service` stops the timer and records `sentiment_response_time_seconds`.  
6. It increments the counter `sentiment_responses_total{sentiment="positive"}` (or relevant sentiment).  
7. Finally, the `app-service` returns the prediction to the user and renders the UI.  

---

## 🧩 Visual Data Flow Diagram

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
    • Increment Counter `sentiment_requests_total{}`  
    • Start timer for Histogram `sentiment_response_time_seconds`  

  P1->>S2: POST /infer {"tweet":"I love cats!"}
  S2->>P2: Route to one of 2 “model-service” Pods

  Note over P2:  
    • Preprocess input (lib-ml)  
    • Increment Counter `sentiment_inference_total{}`  
    • Record Histogram `sentiment_inference_latency_seconds`  

  P2-->>P1: Return JSON { "sentiment":"positive" }
  P1-->>U: Return final JSON + render UI

  Note over P1:  
    • Stop timer → record `sentiment_response_time_seconds`  
    • Increment Counter `sentiment_responses_total{sentiment="positive"}`  

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

---



## 🧭 Dynamic Routing and Canary Releases

- We (will) deploy two versions each of the frontend and backend:  
  - Frontend: `app-service-v1`, `app-service-v2`  
  - Backend: `model-service-v1`, `model-service-v2`  
- The VirtualService (or Ingress rules) direct traffic dynamically with weights, for example:  
  - 90% traffic to `app-service-v1`, 10% to `app-service-v2` (frontend)  
  - Similarly for backend services.  
- This routing enables canary releases and continuous experimentation by gradually shifting traffic.

---

## 🔧 Notes on Cluster Resources

- Each Deployment runs multiple replicas (default: 3) to ensure availability.  
- Services expose pods inside the cluster and allow load balancing.  
- Ingress exposes services externally with domain-based routing.  
- ConfigMaps and Secrets manage configuration and sensitive data.  
- ServiceMonitor integrates with Prometheus for monitoring metrics.

---

## 🎯 Summary

This deployment setup provides a robust, scalable, and flexible infrastructure:  

- Clear separation between frontend and backend services.  
- Support for versioning and canary deployment strategies.  
- Integration with Kubernetes-native resources for easy management.  
- Monitoring ready via Prometheus and Grafana dashboards.

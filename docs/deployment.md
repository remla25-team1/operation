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


## 🌐 Deployment Architecture & Data Flow

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

1. User sends a request to the application via the Ingress controller.  
2. The Ingress routes incoming requests based on host/path rules to the `app-service`.  
3. The `app-service` pods handle frontend and API gateway logic, including serving pages and forwarding model inference requests.  
4. For sentiment analysis, the `app-service` forwards requests to the `model-service`.  
5. The `model-service` pods run the ML inference logic and return predictions.  
6. The `app-service` sends the prediction back to the user.

---

## 🧭 Dynamic Routing and Canary Releases

- We deploy two versions each of the frontend and backend:  
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

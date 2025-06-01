## 1. System Overview

Below is a high-level overview of our final deployment in Kubernetes with Istio. It shows all major components, how they interact, and where dynamic traffic routing decisions occur.  
## 📊 Deployment Architecture Diagram 

```text
                     ┌───────────────────────────────┐
                     │       Internet / Client       │
                     └──────────────┬────────────────┘
                                    │
                     ┌──────────────▼───────────────┐
                     │     Istio IngressGateway     │
                     └──────────────┬───────────────┘
                                    │
                        +-----------+----------------+
                        |     Istio VirtualService   |
                        |     + DestinationRule      |
                        +-----------+----------------+
                                    │
                         ┌──────────▼───────────┐
                         │      Kubernetes       │
                         │       Services        │
                         └──────────┬───────────┘
                                    │
          ┌─────────────────────────┴──────────────────────────┐
          │                                                    │
┌─────────▼──────────┐                            ┌────────────▼───────────┐
│  app-service-v1    │                            │    app-service-v2      │
│  Deployment + Pod  │                            │   Deployment + Pod     │
└─────────┬──────────┘                            └────────────┬───────────┘
          │                                                    │
          ▼                                                    ▼
┌──────────────────┐                                 ┌───────────────────┐
│ model-service-v1 │                                 │ model-service-v2  │
│ Deployment + Pod │                                 │ Deployment + Pod  │
└──────────────────┘                                 └───────────────────┘

                ┌────────────────────────────────────────────────┐
                │         Prometheus (via ServiceMonitor)        │
                └────────────────────────┬───────────────────────┘
                                         │
                           ┌─────────────▼─────────────┐
                           │        Grafana            │
                           └───────────────────────────┘

Other Resources:
- ConfigMap / Secret → Injected into Deployments as env/config
```


In this deployment:  
- **Istio IngressGateway** exposes a single entry point for external HTTP(S) traffic.  
- **VirtualService** and **Gateway** resources route incoming requests through the IngressGateway into the mesh.  
- **DestinationRule** enforces version‐aware routing for both `app-service` and `model-service`, ensuring that consistent pairs of versions handle each user’s traffic.  
- **Deployments** run two versions of the frontend (`app-service-v1`, `app-service-v2`) and two versions of the backend inference service (`model-service-v1`, `model-service-v2`) to support canary releases and continuous experimentation.  
- **Prometheus** and **Grafana** collect and visualize application-specific metrics to support decision-making. Prometheus scrapes metrics from `app-service` and `model-service` Pods via ServiceMonitors.  
- **Kubernetes Service** objects (ClusterIP) front each Deployment, making Pods discoverable.  
- **ConfigMap** and **Secret** provide configuration, environment variables, and credential injection into Pods.  

This design allows us to do canary releases (e.g., 90% of traffic to v1, 10% to v2), support sticky sessions for experiment consistency, and provide continuous-experimentation telemetry for data-driven roll-outs.

---

## 2. Deployment Components

### 2.1 Kubernetes Resources

- **Deployments**  
  - `app-service-v1` / `app-service-v2`  
    - Two versions of the application API (flask-based), each built from separate container images tagged with semantic version (e.g., `app:v1.3.0`, `app:v1.4.0`).  
    - Each Deployment runs one single replica (default is 3) behind a Kubernetes Service.  
    - A single Pod runs the application code, instrumented to expose metrics (e.g., histogram) to Prometheus.  

  - `model-service-v1` / `model-service-v2`  
    - Two versions of the ML inference service (Flask + pre-trained model), with separate container images (e.g., `model-service:2.1.0`, `model-service:2.2.0`).  
    - Each Deployment runs one replica. Pods expose metrics (e.g., histogram) to Prometheus.  

- **Services (ClusterIP)**  
  - `app-service`  
    - Selects Pods labeled `app=app-service` (both v1 and v2 versions).  
    - Listens on port `8080` (HTTP).  
  - `model-service`  
    - Selects Pods labeled `app=model-service`.  
    - Listens on port `8080` (HTTP).  

- **Gateway**  
  - `web-ingress-gateway`  
    - Configures Istio’s IngressGateway to accept external traffic on ports 80 and 443.  
    - Maps the “restaurant-sentiment.example.com” host to our VirtualService.  

- **VirtualService**  
  - `app-virtualservice`  
    - Routes traffic from the IngressGateway to the `app-service` ClusterIP.  
    - Applies weighted routing (e.g., 90% to `app-service-v1`, 10% to `app-service-v2`).  
    - Evaluates HTTP header `end-user` or session cookie for sticky sessions.  
  - `model-virtualservice`  
    - Routes traffic from `app-service` to `model-service`.  
    - Uses header or weight-based routing to ensure that any request served by `app-service-v2` calls `model-service-v2`, and likewise for v1.  

- **DestinationRule**  
  - `app-destinationrule`  
    - Defines subsets `v1` and `v2` for `app-service`, matching on Pod label `version`.  
    - Enables consistent load balancing policy (e.g., `consistentHash` on Cookie for sticky sessions).  
  - `model-destinationrule`  
    - Defines subsets `v1` and `v2` for `model-service`, matching on Pod label `version`.  
    - Ensures that requests from `app-service-v2` always route to `model-service-v2`.  

- **ConfigMap**  
  - `app-config`  
    - Exposes environment variables such as `MODEL_SERVICE_HOST = model-service.default.svc.cluster.local`, `MODEL_SERVICE_PORT = 5000`.  
    - Contains feature flags used by the app for continuous-experiment flags.  
  - `grafana-dashboards-config`  
    - Defines custom Grafana dashboards (JSON) that visualize app-specific metrics and canary comparison charts.  

- **Secret**  
  - `smtp-credentials`  
    - Holds SMTP username/password for Prometheus Alertmanager email notifications.  
  - `db-credentials` *(if applicable)*  
    - Contains username/password for a shared database, e.g., MySQL, if a persistent store is needed.

- **ServiceMonitor** (Prometheus Operator CRD)  
  - `app-servicemonitor`  
    - Targets Kubernetes label `app=app-service` Pods on port `8080/metrics`.  
    - Scrapes custom metrics (Gauge, Counter, Histogram).  
  - `model-servicemonitor`  
    - Targets label `app=model-service` on port `5000/metrics`.  

- **Prometheus Custom Resources**  
  - `prometheusrule-canary`  
    - Defines alert rules (e.g., high error rate in `app-service`, request rate > X/min).  
  - `alertmanagerconfig`  
    - Configured to send an email alert if `app_service_request_rate > 15 per minute for 2 minutes`.

- **Grafana**  
  - A Deployment running Grafana (ingested by Prometheus).  
  - ConfigMap mounts custom dashboards automatically on startup.  
  - Dashboard JSON files live under `operation/docs/images/grafana/*`.  

---

## 3. Traffic Flow & Dynamic Routing

Below is a flowchart illustrating how an external HTTP request progresses through the mesh, from the user’s browser to the inference response, including canary splitting and sticky sessions.

```mermaid
sequenceDiagram
    autonumber
    participant User as External User
    participant Ingress as Istio IngressGateway
    participant VS as app-VirtualService
    participant DR as app-DestinationRule
    participant App as app-service (v1/v2)
    participant VS2 as model-VirtualService
    participant DR2 as model-DestinationRule
    participant Model as model-service (v1/v2)
    User->>Ingress: HTTP GET /predict?review="Great!"
    Ingress->>VS: Forward request (Host header: restaurant-sentiment.example.com)
    
    alt Header "end-user" or Cookie present
        VS->>DR: Route based on cookie (sticky session)
    else No Cookie
        VS->>DR: Weighted routing (90%→v1, 10%→v2)
    end
    
    DR->>App: Forward to specific subset (v1 or v2)
    App->>VS2: Internal HTTP POST /inference {"text":"Great!"}
    
    alt App version = v1
        VS2->>DR2: Route to model-service-v1
    else App version = v2
        VS2->>DR2: Route to model-service-v2
    end
    
    DR2->>Model: Inference, return sentiment JSON
    Model->>App: Return inference result
    App->>User: Render UI with emoji + metrics
   
    Note over App, Model: Prometheus scrapes `/metrics` each 15s via ServiceMonitors
    Note over Prom: Metrics collected: request_count, latency_histogram,… 

    User Request

        The user’s browser sends a GET request to restaurant-sentiment.example.com/predict.

        A sticky-session cookie (e.g., canary-cookie) may already be set if the user was part of a previous experiment.

    Istio IngressGateway

        Listens on port 80/443.

        Matches the Host header and sends traffic to the app-virtualservice.

    VirtualService (app-VS)

        Evaluates:

            If the canary-cookie is present and equals new-model, immediately route 100% to app-service-v2.

            Otherwise, apply weight-based routing (e.g., 90% to v1 subset, 10% to v2 subset).

        Sets a Set-Cookie header canary-cookie=new-model for newly selected canary users.

    DestinationRule (app-DR)

        Maps subset v1 to Pods labeled version=v1 and subset v2 to Pods labeled version=v2.

        Applies consistentHash load balancing keyed on the canary-cookie for sticky sessions.

    app-service Pod (v1 or v2)

        Receives request, calls model-service.

        Starts timer to record request latency; increments Prometheus Counter app_request_total{version="v1"} or v2.

        Forwards to model-virtualservice.

    VirtualService (model-VS)

        Chooses subset in model-service based on HTTP header x-app-version (injected by the app).

        v1 apps set x-app-version:v1, v2 apps set x-app-version:v2.

    DestinationRule (model-DR)

        Routes consistently: subset v1 to Pods labeled version=v1, v2 to Pods labeled version=v2.

    model-service Pod (v1 or v2)

        Performs inference using pre-trained model.

        Records Prometheus metrics:

            model_inference_latency_seconds (Histogram)

            model_inference_errors_total (Counter)

            model_prediction_distribution (Gauge)

    Return Path

        Inference result bubbles back: model → app → user.

        Prometheus scrapes metrics from both services every 15 seconds.

        Grafana dashboard visualizes request rates, latencies, error counts, and canary-v1 vs. v2 comparison.

    Alerting

        PrometheusRule triggers an alert if rate(app_request_total[1m]) > 15 for 2 minutes.

        AlertManager (configured via alertmanagerconfig) sends email to dev-team with alert details (SMTP credentials injected via Secret).


```
## 4. Istio Configuration Summary

Below is a concise summary of the Istio CRDs that implement traffic management, canary rollout, and sticky sessions.
### 4.1 Gateway (web-ingress-gateway)

apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: web-ingress-gateway
  namespace: default
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "restaurant-sentiment.example.com"
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: tls-cert-secret
      hosts:
        - "restaurant-sentiment.example.com"

### 4.2 VirtualService for app-service (app-virtualservice)

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: app-virtualservice
spec:
  hosts:
    - "restaurant-sentiment.example.com"
  gateways:
    - web-ingress-gateway
  http:
    - match:
        - headers:
            cookie:
              regex: ".*canary-cookie=new-model.*"
      route:
        - destination:
            host: app-service
            subset: v2
          weight: 100
    - route:
        - destination:
            host: app-service
            subset: v1
          weight: 90
        - destination:
            host: app-service
            subset: v2
          weight: 10
      headers:
        response:
          set:
            cookie: "canary-cookie=new-model; Path=/; HttpOnly"

### 4.3 DestinationRule for app-service (app-destinationrule)

apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: app-destinationrule
spec:
  host: app-service
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
  trafficPolicy:
    loadBalancer:
      consistentHash:
        httpCookie:
          name: canary-cookie
          ttl: 0s

### 4.4 VirtualService for model-service (model-virtualservice)

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: model-virtualservice
spec:
  hosts:
    - model-service
  http:
    - match:
        - headers:
            x-app-version:
              exact: "v2"
      route:
        - destination:
            host: model-service
            subset: v2
          weight: 100
    - route:
        - destination:
            host: model-service
            subset: v1
          weight: 100

### 4.5 DestinationRule for model-service (model-destinationrule)

apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: model-destinationrule
spec:
  host: model-service
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2

## 5. Resource Inventory

Below is a consolidated list of all deployed resource types and their roles. Readers can refer to our GitHub repository for full YAML definitions.
Resource Type	Name	Purpose
Namespace	default	All resources deployed in the default namespace (for simplicity).
Deployment	app-service-v1 / app-service-v2	Run the application API Pods (v1 and v2)
Deployment	model-service-v1 / model-service-v2	Run the ML inference Pods (v1 and v2)
Deployment	prometheus	Prometheus server deployment (scrapes Istio + app/model metrics)
Deployment	grafana	Grafana server deployment (visualizes metrics)
Service	app-service	ClusterIP fronting both v1/v2 Pods
Service	model-service	ClusterIP fronting both v1/v2 Pods
Service	prometheus	ClusterIP for Prometheus scraping
Service	grafana	ClusterIP for Grafana UI
Gateway	web-ingress-gateway	Istio Ingress gateway for external HTTP(S)
VirtualService	app-virtualservice	Routes web traffic into app-service, weighted canary with sticky sessions
VirtualService	model-virtualservice	Routes app→model traffic based on x-app-version header
DestinationRule	app-destinationrule	Defines subsets for app-service versions and sticky sessions
DestinationRule	model-destinationrule	Defines subsets for model-service versions
ConfigMap	app-config	Injects environment variables, feature flags, and config for app-service
ConfigMap	grafana-dashboards-config	Contains JSON for Grafana dashboards (canary comparison, latency charts)
Secret	smtp-credentials	SMTP creds for Alertmanager to send email notifications
Secret	db-credentials (optional)	Database credentials for a backing store
ServiceMonitor	app-servicemonitor	Prometheus Operator CRD to scrape app-service Pods
ServiceMonitor	model-servicemonitor	Prometheus Operator CRD to scrape model-service Pods
PrometheusRule	prometheusrule-canary	Defines alert rules (e.g., high request rate)
AlertmanagerConfig	alertmanagerconfig	Configures Alertmanager to send alerts via email
HorizontalPodAutoscaler	app-hpa	Auto-scales app-service based on CPU/utilization (optional)
HorizontalPodAutoscaler	model-hpa	Auto-scales model-service based on CPU/utilization (optional)
## 6. Data Flow Description

    External Request Entry

        A user navigates to restaurant-sentiment.example.com in their browser.

        DNS resolves to the external IP of the Kubernetes Ingress Gateway.

        The IngressGateway’s Envoy proxy terminates TLS (if using HTTPS) and forwards the HTTP request to the Istio mesh.

    In‐Mesh Routing & Canary Logic

        The IngressGateway consults app-virtualservice to decide how to route.

            If the user already received a canary-cookie=new-model on a previous visit, their cookie matches the first match condition and 100% of their requests go to app-service-v2.

            Otherwise, weight-based routing sends 90% of new sessions to app-service-v1 and 10% to app-service-v2; a Set-Cookie header is applied to those sent to v2.

    Application Request Processing

        The chosen app-service-vX Pod processes /predict?review=….

        The application performs input validation, increments Prometheus Counter app_request_total{version="vX"}, and records a start timestamp.

        The application sets an HTTP header x-app-version: vX when calling the model inference service.

    Model Inference Request

        Istio’s sidecar for app-service-vX sends the request to model-virtualservice.

        The VirtualService matches on x-app-version=v2 → route to model-service-v2; otherwise route to model-service-v1.

    Inference & Metrics Collection

        model-service-vY Pod receives the request, logs request start time, runs inference with the ML model, records inference latency (Histogram), increments error counter if any.

        The result (sentiment label + confidence) is returned to app-service-vX.

        Prometheus scrapes /metrics from both app and model Pods every 15 seconds via ServiceMonitors.

    Response Back to User

        app-service-vX renders a JSON response (e.g., {"sentiment":"positive","emoji":"😊"}) and records end timestamp to compute latency.

        The response travels back through Istio sidecars → IngressGateway → User browser.

    Monitoring & Alerting

        Prometheus collects and stores time series for:

            app_request_total{version="v1"} and {version="v2"}

            app_request_latency_seconds_bucket{version="vX"} (Histogram)

            model_inference_latency_seconds_bucket{version="vY"} (Histogram)

            model_inference_errors_total{version="vY"} (Counter)

        Grafana dashboards visualize:

            Time series comparison of v1 vs. v2 request rates (Counters + rate function)

            95th percentile latencies for app and model services (Histogram quantile)

            Error counts and error rates (Counter).

        If rate(app_request_total[1m]) > 15 for 2 consecutive minutes, Prometheus fires an alert. AlertManager sends an email using smtp-credentials to dev-team@university.edu.

## 7. Visualizations

Below are the key diagrams included in the docs/images/ folder. Each image is referenced above.
### 7.1 Deployment Architecture Diagram

    File: images/deployment-architecture.png

    Description: Shows all Kubernetes Deployments, Services, Istio Gateways, VirtualServices, DestinationRules, Prometheus, and Grafana within the cluster. Arrows indicate service discovery (ClusterIP) and Istio proxy sidecar communication.

### 7.2 Traffic Routing & Canary Flow

    File: images/traffic-flow.png

    Description: A sequence-style diagram illustrating how user sessions are matched on cookie or weight, then routed to app-service-v1 or v2, and subsequently forwarded to the corresponding model-service subset.

### 7.3 Grafana Dashboard Screenshot

    File: images/grafana-canary-dashboard.png

    Description: Dashboard showing side-by-side comparison of v1 vs. v2 in:

        Request Rate over Time (with rate function)

        95th Percentile Latency for App & Model

        Error Rate

        Canary vs. Baseline metrics aligned by timestamp.

## 8. Resource Connections (Visual)

Below is a compact representation of resource types and high-level relationships. This is best used as a quick reference.

graph LR
  subgraph Istio-Mesh
    IngressGateway[Istio IngressGateway]
    VS_App[VirtualService<br/>app-virtualservice]
    DR_App[DestinationRule<br/>app-destinationrule]
    VS_Model[VirtualService<br/>model-virtualservice]
    DR_Model[DestinationRule<br/>model-destinationrule]
  end

  subgraph Kubernetes
    subgraph AppStack
      ASv1[Deployment<br/>app-service-v1]
      ASv2[Deployment<br/>app-service-v2]
      Service_app[Service<br/>app-service]
    end

    subgraph ModelStack
      MSv1[Deployment<br/>model-service-v1]
      MSv2[Deployment<br/>model-service-v2]
      Service_model[Service<br/>model-service]
    end

    subgraph Monitoring
      Prom[Deployment<br/>prometheus]
      Graf[Deployment<br/>grafana]
      SM_App[ServiceMonitor<br/>app-servicemonitor]
      SM_Model[ServiceMonitor<br/>model-servicemonitor]
      PR_Canary[PrometheusRule<br/>prometheusrule-canary]
      AM_Config[AlertmanagerConfig]
    end
  end

  User -- HTTP request --> IngressGateway
  IngressGateway -- Host match --> VS_App
  VS_App -- Route/Weight --> DR_App
  DR_App -- Subset v1/v2 --> Service_app
  Service_app -- Pod DNS --> ASv1 & ASv2

  ASv1 -- x-app-version: v1 --> VS_Model
  ASv2 -- x-app-version: v2 --> VS_Model

  VS_Model -- Route Header --> DR_Model
  DR_Model -- Subset v1/v2 --> Service_model
  Service_model -- Pod DNS --> MSv1 & MSv2

  ASv1 & ASv2 -- expose /metrics --> SM_App
  MSv1 & MSv2 -- expose /metrics --> SM_Model

  SM_App & SM_Model -- scrape --> Prom
  Prom -- send metrics --> Graf

  PR_Canary -- define alerts --> Prom
  AM_Config -- configure email --> Prom

## 9. Conclusion

This document detailed the final deployment of our Restaurant Sentiment Analysis application in a Kubernetes cluster with Istio service mesh. We covered:

    System Overview – The entry point (IngressGateway), service mesh components, and monitoring stack.

    Deployment Components – All Kubernetes and Istio resources (Deployments, Services, Gateway, VirtualService, DestinationRule, ConfigMap, Secret, ServiceMonitor, PrometheusRule, AlertmanagerConfig, etc.).

    Traffic Flow – Step-by-step request flow from user to app → model, including canary weight logic and sticky sessions.

    Istio Config Summary – YAML snippets for Gateway, VirtualService, and DestinationRule resources.

    Resource Inventory – Table listing each resource type, name, and purpose.

    Data Flow & Metrics – How Prometheus gathers metrics, how Grafana dashboards visualize them, and how alerts are triggered.

    Visualizations – Diagrams (architecture, traffic flow, Grafana screenshot) that clarify the setup.

A new team member can use this document to quickly understand the architecture, the dynamic routing decisions in our continuous experimentation, and how metrics drive our canary-release decisions. For full YAML definitions and image files, see our GitHub repository under the operation/docs/ directory.
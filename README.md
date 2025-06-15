# REMLA-25, Team 1, Operation
This repository contains a modular tweet sentiment analysis system, organized into six individual repositories under the `remla25-team1` organization:

* **app**: Front-end application and API gateway responsible for serving pages and forwarding model inference requests.
* **model-service**: Microservice for handling sentiment classification requests, interfacing with the preprocessing library and the trained model.
* **model-training**: Training pipeline to build and export sentiment classification models.
* **lib-ml**: Shared preprocessing library for text cleaning, tokenization, and feature extraction.
* **lib-version**: Versioning library to manage and expose the current application version.
* **operation**: Deployment and orchestration artifacts (e.g., Docker, Kubernetes manifests) for the end-to-end system.

Each component can be developed, tested, and deployed independently, yet they form a cohesive machine learning-powered web service.

## Contents

- [Install & Run](#install--run)
- [Clone the Repository](#clone-the-repository)
- [Running Application on Kubernetes Cluster](#running-application-on-kubernetes-cluster)
- [Other Commands](#other-commands)
- [Other Useful Stuff](#other-useful-stuff)
- [Helm](#helm)
- [Setup Prometheus](#setup-prometheus)
- [Grafana](#grafana)
  - [Auto-load via ConfigMap](#auto-load-via-configmap)
  - [Import the Dashboard Manually](#import-the-dashboard-manually)
- [Testing Istio](#testing-istio)

## Install & Run

Make sure you have the following installed:
- [Docker & Docker Compose](https://docs.docker.com/compose/install/)
- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html)
- [Kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)


## Clone the Repository

Clone the **operation** repository from GitHub (e.g., using SSH):

   ```bash
   git clone git@github.com:remla25-team1/operation.git
   cd operation
   ```

## Running Application on Kubernetes Cluster
Navigate into ```operation``` dir and run the code below. Set up a ```imagePullSecrets``` for GHCR: first generate a new token (classic) on Github. Give it scopes ```read:packages, repo```. Copy the token and paste it in the command below:

```bash
chmod +x run-all.sh
./run-all.sh
```

This will set up all services. The script takes a good while to run, so take your time. During step 3 of the process (indicated in the terminal), you will be asked for your Github username, PAT token, and Github email address. This is so that you can pull the latest images to deploy on the cluster.
You will be asked for your ```BECOME``` password. This is so that the playbook can run commands in ```sudo``` mode. Simply fill in your host password here.

At the end of the script, you will be asked to execute the following command, so that you can execute ```kubectl``` commands in the terminal:
```bash
export KUBECONFIG=$(pwd)/kubeconfig-vagrant
echo $KUBECONFIG
# it should output /path/to/project/operation/kubeconfig-vagrant
```

NOTE: for any new shell you spawn, you need to repeat this exporting of the ```KUBECONFIG``` variable.


If you want to upgrade the service to adapt any changes, just rerun

```bash
./run-all.sh
```

When you are finished, tear down the cluster with
```bash
chmod +x cleanup.sh
./cleanup.sh
```

```bash
kubectl describe ingress app-ingress
# Name:             app-ingress
# Labels:           <none>
# Namespace:        default
# Address:          
# Ingress Class:    <none>
# Default backend:  <default>
# Rules:
#   Host        Path  Backends
#   ----        ----  --------
#   app.local   
#               /   app:8080 (10.244.2.29:8080)
# Annotations:  nginx.ingress.kubernetes.io/rewrite-target: /
# Events:       <none>
kubectl get svc app
# NAME   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
# app    NodePort   10.96.110.197   <none>        8080:32045/TCP   140m
kubectl get endpoints app
# NAME   ENDPOINTS          AGE
# app    10.244.2.29:8080   140m
```

#### Other useful commands:
- Triger a rollout restart:
```bash
kubectl rollout restart deployment app
kubectl rollout restart deployment model-service
```

- Deleting existing pods manually (only safe if the app is stateless):
```bash
kubectl delete pods --all
kubectl delete pods -l app=app
kubectl delete pods -l app=model-service
``` 

- Inspecting all config maps installed in the cluster:
```bash
kubectl get configmaps
# NAME                 DATA   AGE
# application-config   6      52m
# kube-root-ca.crt     1      4h33m
```

- Pushing new Docker image of a repo so that it can be deployed on the running cluster (```app``` example):
```bash
docker build -t ghcr.io/remla25-team1/app:latest .
echo YOUR_TOKEN_HERE | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
 # this requires you to have a GHCR token for writing packages (you might want to store it too)
docker push ghcr.io/remla25-team1/app:latest 

# trigger a Deployment restart to pull the new image (ssh into ctrl node!)
kubectl rollout restart deployment app
#deployment.apps/app restarted

# check the rollout status
kubectl rollout status deployment app
# deployment "app" successfully rolled out

# confirm that the new pod is running (below, you can see the age difference)
kubectl get pods -o wide
# NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE         NOMINATED NODE   READINESS GATES
# app-778466bdff-mzjxl            1/1     Running   0          82s   10.244.2.7   k8s-node-2   <none>           <none>
# model-service-5987884b9-mjjln   1/1     Running   0          46m   10.244.1.7   k8s-node-1   <none>           <none>
```

## Check if Prometheus works

### 1. Access Prometheus Web UI
```sh
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Open [http://localhost:9090](http://localhost:9090) in your browser.

To verify that your metrics endpoints are being scraped:

- Go to the Prometheus UI (`Status` → `Targets`)
- Look for your application's Service name or Pod name in the targets list
- Check the status (should be "UP")

### 2. Test if metrics endpoint is reachable from inside the cluster

```sh
kubectl port-forward svc/sentiment-app-app 8080:8080

curl http://localhost:8080/metrics
```

## Test Alerting Capabilities 

### 1. Create a Kubernetes Secret for SMTP Credentials

Use the following command to create a secret containing fake (or real, for production) SMTP credentials.

```bash
kubectl create secret generic alertmanager-smtp-secret \
  --from-literal=smtp_username=fake-user@example.com \
  --from-literal=smtp_password=fake-password \
  -n monitoring
```

### 2. Re-deploy the Application 

Re-run the deployment to apply changes, including alerting configuration:
```bash
./run-all.sh
```
This ensures that Alertmanager picks up the config and mounts the secret properly.

### 3. Access Prometheus and Locate the Alert

Forward Prometheus to your local machine:
```sh
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Then open your browser and visit:
[http://localhost:9090](http://localhost:9090)

Look for the custom alert "HighRequestRate" in the list. If it's correctly configured and active, it will appear as Inactive, Pending or Firing.

### 4. Trigger the Alert by Generating Traffic

To exceed the alert threshold, simulate traffic:
```bash
while true; do curl -s http://192.168.56.91:80/; sleep 0.1; done
```
This generates approximately 10 requests per second, which is well above the threshold.

### 5. Verify Alert Status and Email Notification

In the Prometheus UI under **Alerts**, verify that the alert transitions from **Pending** to **Firing** after approximately 2m. 

Check the Alertmanager UI to confirm that it received and processed the alert:

```bash
kubectl port-forward -n monitoring svc/alertmanager-operated 9093
```

Then visit: [http://localhost:9093](http://localhost:9093)
You should see the alert listed there, with the configured receiver (email, etc.).

## Grafana 
We provide a pre-configured dashboard for monitoring with 4 pannels:

- Request count by sentiment (sentiment_requests_total)

- Average response time (sentiment_response_time_seconds)

- Correction submission stats (correction_requests_total)

- In-progress requests (sentiment_requests_in_progress)

### Auto-load via ConfigMap (Not available yet.)
```bash
kubectl apply -f dashboard/tweet-sentiment-dashboard-configmap.yaml
```

### Import the dashboard manually 
- Open Grafana 
   - Access to grafana:
      ```bash
      kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
      ```
      - Then open: http://localhost:3000
      - Username: admin
      - Password: prom-operator
      
- Go to Dashboards → Import

- Upload: monitoring/tweet-sentiment-dashboard.json (Not available yet. You need to create view)

- Select Prometheus as data source, click Import


## Testing Istio
The cluster is configured with Istio in the ```migrate.yaml``` playbook which you ran above. To test the Istio traffic management functionality, you can try the following two tests:
```bash
# find the INGRES-IP (external ip below)
kubectl -n istio-system get svc istio-ingressgateway
# NAME                   TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                                                                      AGE
# istio-ingressgateway   LoadBalancer   10.98.33.145   192.168.56.91   15021:32752/TCP,80:31897/TCP,443:31145/TCP,31400:30170/TCP,15443:31601/TCP   18m

# testing sticky sessions
for i in {1..10}; do
  curl -s http://<INGRESS_IP>/
  echo
done

curl -H "user-group: canary" http://<INGRESS_IP>/
```

## Use-Case: Tweet Sentiment Analysis

Our application features a simple interface where users can enter a tweet to analyze its sentiment. When submitted, the backend runs a sentiment analysis model and displays the predicted sentiment. The user then sees whether the tweet is positive or negative, and can confirm or correct this prediction. This feedback helps improve the model and makes the app more interactive and accurate over time.

### Negative Comment
![alt text](cases/negative.png)

[Original tweet available here](https://x.com/JtheCat3/status/1864351776868094126)

### Positive Comment
![alt text](cases/positive.png)

[Original tweet available here](https://x.com/TinuKuye/status/1719440898696630564)

### Correct Predictions
![alt text](cases/correction.png)

[Original tweet available here](https://x.com/TinuKuye/status/1719440898696630564)


## Related Repositories

* [app](https://github.com/remla25-team1/app)
* [model-service](https://github.com/remla25-team1/model-service)
* [model-training](https://github.com/remla25-team1/model-training)
* [lib-ml](https://github.com/remla25-team1/lib-ml)
* [lib-version](https://github.com/remla25-team1/lib-version)
* [operation](https://github.com/remla25-team1/operation)

## Auto-update version tags in PEER.md
Navigate to project root and run (in a virtual environment):
```
pip install -r scripts/requirements.txt
python scripts/peer-release.py
```
## Progress Log

**model-service**: Implemented core sentiment analysis module in `model-service`, leveraging a baseline logistic regression model for binary classification, and designed the HTTP endpoint to accept raw comments and return sentiment labels.

**app(app-frontend, app-service)**: Developed the `app` front-end with React, integrated request forwarding logic to the `model-service`, and added client-side version display using the `lib-version` service.

**lib-version**: Created the `lib-version` library with semantic versioning support, implemented an HTTP server to expose version information.

**lib-ml**: Built the `lib-ml` preprocessing pipeline, integrated the library into `model-service` for consistent preprocessing.

**model-training**: Completed the `model-training` pipeline: read datasets, trained models, and exported the model artifact for inference in `model-service`.

**operation**: Provides a simple Dockerfile setup along with clear documentation for running the entire system locally.

---

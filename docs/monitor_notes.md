Here is some commands that might be useful

## 1. Access Prometheus Web UI
```sh
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Open [http://localhost:9090](http://localhost:9090) in your browser.

To verify that your metrics endpoints are being scraped:

- Go to the Prometheus UI (`Status` → `Targets`)
- Look for your application's Service name or Pod name in the targets list
- Check the status (should be "UP")


## 2. For Prometheus Troubleshooting


### List all Prometheus-related services in the monitoring namespace

```sh
kubectl get svc -n monitoring
```

### Check ServiceMonitor resources

```sh
kubectl get servicemonitor -A
kubectl describe servicemonitor <servicemonitor-name> -n <namespace>
```

### Check if your application's Service is labeled correctly

```sh
kubectl get svc -n <your-app-namespace> --show-labels
```

### Test if metrics endpoint is reachable from inside the cluster

```sh
kubectl port-forward svc/sentiment-app-app 8080:8080

curl http://localhost:8080/metrics
```


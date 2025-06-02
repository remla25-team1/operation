## Experiment Goal
In v2, we added a Redis cache layer in front of the model inference logic.

## Hypothesis
We hypothesize that `app:v2` will have a lower average `sentiment_response_time` compared to `v1`.

## Metrics
- `sentiment_response_time_hist` (Histogram)
- `sentiment_response_time_seconds_count`

### Experiment Setup
- Both versions are deployed using separate Deployments (v1 and v2).
    - v1: `ghcr.io/remla25-team1/app:0.0.6-pre-20250528-002`
    - v2: `ghcr.io/remla25-team1/app:0.0.6-pre-20250602-001`
- Istio VirtualService routes 90% of traffic to v1, and 10% to v2.
- Prometheus scrapes app-specific metrics, and Grafana visualizes latency distribution.

### Result


### Decision



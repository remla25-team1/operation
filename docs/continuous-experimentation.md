## Experiment Goal
In v2, we added a Redis cache layer in front of the model inference logic.

## Hypothesis
We hypothesize that `app:v2` will have a lower average `sentiment_response_time` compared to `v1`.

### Experiment Setup
- Both versions are deployed using separate Deployments (v1 and v2).
    - v1: [`ghcr.io/remla25-team1/app:0.0.6-pre-20250528-002`](https://github.com/remla25-team1/app/releases/tag/v0.0.6-pre-20250528-002)
    - v2: [`ghcr.io/remla25-team1/app:0.0.6-pre-20250602-001`](https://github.com/remla25-team1/app/releases/tag/v0.0.6-pre-20250602-001)
- Istio VirtualService routes 90% of traffic to v1, and 10% to v2.
- Prometheus scrapes app-specific metrics, and Grafana visualizes latency distribution.


## Metrics
The metric used is a histogram, and the average response time is calculated using the standard PromQL formula:
(a)
```
sum by (app_version, source) (
  rate(sentiment_response_time_seconds_sum[$__interval])
)
/
sum by (app_version, source) (
  rate(sentiment_response_time_seconds_count[$__interval])
)
```

(b)
```
#Query A:

sum by (app_version) (
  rate(sentiment_response_time_seconds_sum{app_version="0.0.6-pre-20250617-001"}[$__interval])
)
/
sum by (app_version) (
  rate(sentiment_response_time_seconds_count{app_version="0.0.6-pre-20250617-001"}[$__interval])
)


# Query B:
sum by (app_version) (
  rate(sentiment_response_time_seconds_sum{app_version="0.0.6-pre-20250617-003"}[$__interval])
)
/
sum by (app_version) (
  rate(sentiment_response_time_seconds_count{app_version="0.0.6-pre-20250617-003"}[$__interval])
)

```

They compute the smoothed average latency over time, combining total observed durations and total request counts.

### Result
The screenshot below shows the Prometheus metrics collected during the experiment. 

![ABtest1](images/AB_test_1.png)
![ABtest2](images/AB_test_2.png)

### Observations
App version `0.0.6-pre-20250617-001` uses only model inference and achieves an average response time of `~0.0173s`.

App version `0.0.6-pre-20250617-003` introduces Redis caching, resulting in:

Cache responses: `~0.00025s`

Model responses: `~0.0330s`

Combined average: `~0.00353s`



### Decision
Version `0.0.6-pre-20250617-003` performs significantly better than `001` in terms of response time.

With caching, most responses in `003` return almost instantly (`~0.25ms`).

Its overall average response time is much lower than `001` (`0.0035s` vs. `0.0173s`).

Although model responses in `003` are slightly slower, the impact is minimal due to high cache usage.

Thus, We choose version `003` for deployment, as it provides much faster responses with no negative impact on correction rate.



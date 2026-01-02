# Observability Strategies

## RED Method (services)

- Rate: requests per second
- Errors: failed requests (4xx/5xx)
- Duration: latency distribution (p50, p90, p99)

Use RED for user-facing services and APIs.

## USE Method (resources)

- Utilization: % busy (CPU, memory, disk)
- Saturation: queue length or load
- Errors: errors in resource components

Use USE for infrastructure or platform components.

## Golden Signals (Google SRE)

- Latency
- Traffic
- Errors
- Saturation

Use Golden Signals when you need a broad, standardized health view.

## Selection Guidance

- Service dashboards: RED + Golden Signals
- Infrastructure dashboards: USE + Golden Signals
- Business dashboards: define custom signals, but keep latency/traffic/errors visible
# Application Monitoring with Prometheus

How to expose and scrape metrics from Spring Boot, Langflow, and Node.js applications.

---

## Spring Boot

### Step 1 — Add Dependencies (Maven)

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

### Step 2 — Enable Prometheus Endpoint

In `application.properties`:

```properties
management.endpoints.web.exposure.include=health,prometheus
management.endpoint.prometheus.enabled=true
```

### Step 3 — Verify Metrics Endpoint

```bash
curl http://<app-ip>:8080/actuator/prometheus
```

You should see a long list of JVM, HTTP, and custom metrics.

### Step 4 — Add to Prometheus Config

```yaml
- job_name: 'springboot-app'
  metrics_path: '/actuator/prometheus'
  static_configs:
    - targets: ['<app-ip>:8080']
      labels:
        instance: 'springboot-prod'
```

### Recommended Grafana Dashboard

Import dashboard ID **`4701`** (JVM Micrometer) for:
- Heap and non-heap memory
- GC pause times
- HTTP request rates and latencies
- Thread counts

---

## Langflow

Langflow exposes a `/metrics` endpoint when running.

### Prometheus Config

```yaml
- job_name: 'langflow'
  metrics_path: /metrics
  static_configs:
    - targets: ['<langflow-ip>:7860']
      labels:
        instance: 'langflow-prod'
```

### Verify

```bash
curl http://<langflow-ip>:7860/metrics
```

---

## Node.js

Use the `prom-client` library to expose metrics from a Node.js app.

### Install

```bash
npm install prom-client
```

### Expose Metrics Endpoint

```javascript
const client = require('prom-client');
const express = require('express');
const app = express();

// Collect default metrics (CPU, memory, event loop lag)
client.collectDefaultMetrics();

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

### Prometheus Config

```yaml
- job_name: 'nodejs'
  metrics_path: /metrics
  static_configs:
    - targets: ['<app-ip>:3000']
      labels:
        instance: 'nodejs-prod'
```

---

## Full prometheus.yml with All Applications

See [`configs/prometheus.yml`](../configs/prometheus.yml) for the complete multi-target config.

---

## Useful PromQL Queries

```promql
# CPU usage per instance
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage %
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# Disk usage %
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# HTTP request rate (Spring Boot)
rate(http_server_requests_seconds_count[5m])

# JVM heap usage
jvm_memory_used_bytes{area="heap"}
```

---

**Next:** [Wazuh Installation](04-wazuh-installation.md)

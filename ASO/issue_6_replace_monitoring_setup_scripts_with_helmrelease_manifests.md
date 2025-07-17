# Replace Monitoring Setup Scripts with HelmRelease Manifests

Labels: monitoring, helm, flux

As a platform engineer  
I want to deploy Prometheus and Grafana using HelmRelease  
So that monitoring stack provisioning is Flux-native and declarative

### Acceptance Criteria
- `HelmRelease` manifests for Prometheus and Grafana stored in `apps/monitoring/`
- Custom `values.yaml` configured with appropriate datasources and dashboards
- Flux successfully deploys charts on top of ASO-managed cluster
- Goss or curl-based tests confirm availability of metrics endpoints

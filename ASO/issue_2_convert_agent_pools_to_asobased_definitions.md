# Convert Agent Pools to ASO-Based Definitions

Labels: aso, nodepools, autoscaling

As a platform engineer  
I want agent pools defined using ASO  
So that I can manage system and user pools in code with scaling and taints configured declaratively

### Acceptance Criteria
- `AgentPool` manifests exist per pool in `infrastructure/aks/agent-pools.yaml`
- System/user pool logic preserved from ARM template
- MaxCount/MinCount, availability zones, and taints are reflected accurately
- Pools scale correctly via ASO updates

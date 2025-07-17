That’s a smart and scalable approach. You can achieve this in InSpec by:

⸻

✅ Goal

Use a YAML environment file to pass values like:

subscription_id: xxxx
resource_group: aks-dev-weu-001
cluster_name: dev-aks-01
keyvault_name: dev-kv-01
uami_name: aks-uami-dev

And reference these dynamically in your InSpec controls.

⸻

🔧 Step-by-Step Setup

1. 📁 Add a YAML config file

Create one per environment:

tests/inspec/envs/dev.yaml
tests/inspec/envs/staging.yaml

Example dev.yaml

subscription_id: abc12345
resource_group: aks-dev-weu-001
cluster_name: dev-aks-01
keyvault_name: dev-kv-01
uami_name: aks-uami-dev


⸻

2. 🧪 Update Your inspec.yml to Load Inputs

name: ubs-aso-infra-profile
title: ASO Infrastructure Compliance
version: 0.1.0
supports:
  - platform: azure
inputs:
  - name: subscription_id
  - name: resource_group
  - name: cluster_name
  - name: keyvault_name
  - name: uami_name


⸻

3. ✍️ Modify InSpec Controls to Use Inputs

aks_profile.rb

resource_group = input('resource_group')
cluster_name = input('cluster_name')

control 'aks-rbac-enabled' do
  impact 1.0
  title 'AKS cluster should have RBAC enabled'
  describe azurerm_kubernetes_cluster(resource_group: resource_group, name: cluster_name) do
    its('enable_rbac') { should cmp true }
  end
end


⸻

4. 🧪 Run InSpec With YAML Inputs (Locally)

inspec exec . -t azure:// --input-file envs/dev.yaml


⸻

5. ✅ GitLab CI: Support Input Files

Update your job to dynamically use the YAML file:

inspec_validate:
  stage: test
  image: chef/inspec:latest
  script:
    - cd tests/inspec
    - inspec exec . -t azure:// --input-file envs/$ENV.yaml --reporter cli json:inspec_report.json
  artifacts:
    paths:
      - tests/inspec/inspec_report.json
  rules:
    - if: '$PIPELINE_TYPE == "provision" || $PIPELINE_TYPE == "day2"'
      when: manual

This uses the GitLab $ENV variable to pick the right environment file (dev, staging, etc.).

⸻

📦 Summary Folder Layout

tests/inspec/
├── envs/
│   ├── dev.yaml
│   └── staging.yaml
├── controls/
│   ├── aks_profile.rb
│   └── keyvault_profile.rb
├── inspec.yml


⸻

Would you like:
	•	A downloadable InSpec bundle with dynamic inputs pre-configured?
	•	A helper script to generate env.yaml from your existing cluster metadata?
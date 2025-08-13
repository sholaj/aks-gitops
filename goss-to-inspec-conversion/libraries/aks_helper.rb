# encoding: utf-8
# copyright: DevOps Team

# AKS Helper Library
# Provides utility methods for AKS compliance testing

class AKSHelper
  def self.validate_kubernetes_version(actual_version, expected_version)
    # Remove 'v' prefix if present and compare
    actual = actual_version.gsub(/^v/, '')
    expected = expected_version.gsub(/^v/, '')
    
    actual == expected
  end

  def self.check_pod_status(namespace, label_selector)
    cmd = "kubectl get pods -n #{namespace}"
    cmd += " -l #{label_selector}" unless label_selector.empty?
    cmd += " -o jsonpath='{.items[*].status.phase}'"
    
    result = inspec.command(cmd)
    return false unless result.exit_status == 0
    
    phases = result.stdout.strip.split
    phases.all? { |phase| phase == 'Running' }
  end

  def self.validate_azure_resource_exists(resource_type, name, resource_group)
    cmd = case resource_type
          when 'identity'
            "az identity show --name #{name} --resource-group #{resource_group}"
          when 'aks'
            "az aks show --name #{name} --resource-group #{resource_group}"
          else
            return false
          end
    
    result = inspec.command(cmd)
    result.exit_status == 0
  end

  def self.get_federated_credential_count(identity_name, resource_group)
    cmd = "az identity federated-credential list --identity-name #{identity_name} --resource-group #{resource_group} | jq length"
    result = inspec.command(cmd)
    
    return 0 unless result.exit_status == 0
    result.stdout.strip.to_i
  end

  def self.validate_flux_component_health(namespace, component)
    label_selectors = {
      'source-controller' => 'app=source-controller',
      'kustomize-controller' => 'app=kustomize-controller',
      'helm-controller' => 'app=helm-controller',
      'image-automation-controller' => 'app=image-automation-controller',
      'fluxconfig-agent' => 'app.kubernetes.io/component=fluxconfig-agent',
      'fluxconfig-controller' => 'app.kubernetes.io/component=fluxconfig-controller'
    }

    selector = label_selectors[component]
    return false unless selector

    check_pod_status(namespace, selector)
  end

  def self.validate_daemonset_rollout(namespace, daemonset_name)
    # Check if daemonset rollout is complete
    cmd = "kubectl --namespace #{namespace} rollout status daemonset/#{daemonset_name} --timeout=30s"
    rollout_result = inspec.command(cmd)
    
    return false unless rollout_result.exit_status == 0 && rollout_result.stdout.include?('successfully rolled out')
    
    # Check if desired number equals ready number
    cmd = "kubectl --namespace #{namespace} get daemonset #{daemonset_name} -o json | jq -r 'select(.status.desiredNumberScheduled == .status.numberReady).metadata.name'"
    status_result = inspec.command(cmd)
    
    status_result.exit_status == 0 && status_result.stdout.strip == daemonset_name
  end

  def self.validate_crd_exists(crd_name)
    cmd = "kubectl get crd #{crd_name}"
    result = inspec.command(cmd)
    result.exit_status == 0
  end

  def self.get_cluster_issuer_status(issuer_name)
    cmd = "kubectl get clusterissuers #{issuer_name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'"
    result = inspec.command(cmd)
    
    return 'Unknown' unless result.exit_status == 0
    result.stdout.strip
  end

  def self.validate_external_secret_sync(secret_name, namespace)
    cmd = "kubectl get externalsecrets #{secret_name} -n #{namespace} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")].status}'"
    result = inspec.command(cmd)
    
    return false unless result.exit_status == 0
    result.stdout.strip == 'True'
  end

  def self.check_configmap_content(namespace, configmap_name, pattern)
    cmd = "kubectl --namespace #{namespace} get configmap #{configmap_name} -o yaml"
    result = inspec.command(cmd)
    
    return false unless result.exit_status == 0
    result.stdout.match?(pattern)
  end
end
control 'aks-version-1.32' do
  title 'AKS cluster should be running Kubernetes version 1.32.x'
  desc 'Verify that the AKS cluster is running a supported Kubernetes version in the 1.32.x series'
  impact 1.0
  tag severity: 'high'
  tag category: 'version-compliance'

  # Get cluster information
  cluster = azure_aks_cluster(
    resource_group: input('resource_group_name'),
    name: input('aks_cluster_name')
  )

  describe cluster do
    it { should exist }
    its('kubernetes_version') { should match(/^1\.32\./) }
  end

  # Additional detailed checks
  describe "AKS cluster #{input('aks_cluster_name')}" do
    subject { cluster.kubernetes_version }
    
    it 'should be version 1.32.x' do
      expect(subject).to match(/^1\.32\./)
    end

    it 'should not be an older version' do
      major_minor = subject.split('.')[0..1].join('.')
      expect(major_minor).to eq('1.32')
    end
  end

  # Log current version for troubleshooting
  describe cluster do
    its('kubernetes_version') { should_not be_nil }
  end

  only_if do
    cluster.exists?
  end
end
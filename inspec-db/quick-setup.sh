#!/bin/bash

# Quick Setup Script - One-command setup for database clients
# Downloads binaries directly from URLs and sets up VM for testing

set -e

echo "╔══════════════════════════════════════════════╗"
echo "║   Database Client Quick Setup for RHEL 8    ║"
echo "║         Direct Download & VM Setup          ║"
echo "╔══════════════════════════════════════════════╝"
echo ""

# Check for required tools
check_requirements() {
    echo "Checking requirements..."
    
    if ! command -v vagrant &> /dev/null; then
        echo "❌ Vagrant not found. Installing..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install vagrant
            else
                echo "Please install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                exit 1
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install vagrant
        else
            echo "Please install Vagrant manually from: https://www.vagrantup.com/downloads"
            exit 1
        fi
    fi
    
    if ! command -v VBoxManage &> /dev/null; then
        echo "⚠️  VirtualBox not found. Please install from: https://www.virtualbox.org/wiki/Downloads"
        echo "   Or use: brew install --cask virtualbox (macOS)"
        exit 1
    fi
    
    echo "✅ All requirements met"
}

# Main setup
main() {
    # Check requirements
    check_requirements
    
    echo ""
    echo "Select setup option:"
    echo "1) Download database client binaries only"
    echo "2) Download Ansible binaries only"
    echo "3) Download both database clients and Ansible"
    echo "4) Setup local VM with database clients"
    echo "5) Complete setup - Download everything and setup VM"
    read -p "Choice (1-5): " choice
    
    case $choice in
        1)
            echo ""
            echo "📦 Downloading database client binaries..."
            chmod +x download-binaries.sh
            ./download-binaries.sh
            echo ""
            echo "✅ Database clients download complete!"
            echo "Transfer db-binaries-*.tar.gz to your airgapped system."
            ;;
        2)
            echo ""
            echo "📦 Downloading Ansible binaries..."
            chmod +x download-ansible-binary.sh
            ./download-ansible-binary.sh
            echo ""
            echo "✅ Ansible download complete!"
            echo "Transfer ansible-binaries-*.tar.gz to your airgapped system."
            ;;
        3)
            echo ""
            echo "📦 Downloading database client binaries..."
            chmod +x download-binaries.sh
            ./download-binaries.sh
            
            echo ""
            echo "📦 Downloading Ansible binaries..."
            chmod +x download-ansible-binary.sh
            ./download-ansible-binary.sh
            
            echo ""
            echo "✅ All downloads complete!"
            echo "Transfer both .tar.gz files to your airgapped system."
            ;;
        4)
            echo ""
            echo "🖥️  Setting up local VM..."
            cd vagrant-vm-setup
            vagrant up
            echo ""
            echo "✅ VM setup complete!"
            echo ""
            echo "Access VM with: vagrant ssh"
            echo "VM IP: 192.168.56.10"
            ;;
        5)
            echo ""
            echo "📦 Downloading database client binaries..."
            chmod +x download-binaries.sh
            ./download-binaries.sh
            
            echo ""
            echo "📦 Downloading Ansible binaries..."
            chmod +x download-ansible-binary.sh
            ./download-ansible-binary.sh
            
            echo ""
            echo "🖥️  Setting up VM..."
            cd vagrant-vm-setup
            vagrant up
            
            echo ""
            echo "✅ Complete setup finished!"
            echo ""
            echo "Downloaded packages:"
            echo "  - db-binaries-*.tar.gz"
            echo "  - ansible-binaries-*.tar.gz"
            echo "VM access: cd vagrant-vm-setup && vagrant ssh"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    
    echo ""
    echo "📋 Next Steps:"
    echo "─────────────"
    
    if [[ "$choice" == "1" ]] || [[ "$choice" == "3" ]] || [[ "$choice" == "5" ]]; then
        echo "For database clients (airgapped system):"
        echo "1. Transfer db-binaries-*.tar.gz to target system"
        echo "2. Extract: tar xzf db-binaries-*.tar.gz"
        echo "3. Install: cd db-binaries-* && ./install.sh"
        echo "4. Test: ./test-clients.sh"
        echo ""
    fi
    
    if [[ "$choice" == "2" ]] || [[ "$choice" == "3" ]] || [[ "$choice" == "5" ]]; then
        echo "For Ansible (airgapped system):"
        echo "1. Transfer ansible-binaries-*.tar.gz to target system"
        echo "2. Extract: tar xzf ansible-binaries-*.tar.gz"
        echo "3. Install: cd ansible-binaries-* && ./install-ansible.sh"
        echo "4. Test: ansible --version"
        echo "5. Deploy DB clients: ansible-playbook install-db-clients.yml -i inventory.ini"
        echo ""
    fi
    
    if [[ "$choice" == "4" ]] || [[ "$choice" == "5" ]]; then
        echo "For local VM testing:"
        echo "1. Access VM: cd vagrant-vm-setup && vagrant ssh"
        echo "2. Test tools: sqlcmd -? && sqlplus -version && isql --version"
        echo "3. Run tests: cd ~/db-tests && ./test-connections.sh"
        echo ""
    fi
    
    echo "📚 Documentation:"
    echo "- Setup guide: database-connectivity-setup.md"
    echo "- Direct URLs: direct-download-urls.md"
    echo "- VM setup: vagrant-vm-setup/README.md"
    echo "- Ansible setup: download-ansible-binary.sh (has embedded README)"
    echo ""
    echo "🧪 Testing:"
    echo "chmod +x db-connectivity-tests.sh"
    echo "./db-connectivity-tests.sh --help"
}

# Run main
main
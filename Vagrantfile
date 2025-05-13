NUM_WORKERS = 2
CTRL_CPUS = 1
CTRL_MEM = 2048 # 2 GB
WORKER_CPUS  = 2
WORKER_MEM = 6144 # 6 GB

Vagrant.configure("2") do |config|

  config.vm.box = "bento/ubuntu-24.04"
  config.vm.box_version = "202502.21.0" # for reproducibility

  cluster_network = "192.168.57"

  config.vm.synced_folder "./ssh_keys", "/vagrant/ssh_keys"

  # Defining the ctrl VM
  config.vm.define "ctrl" do |ctrl|

    # General settings
    ctrl.vm.hostname = "k8s-ctrl"
    ctrl.vm.provider "virtualbox" do |vb|
      vb.name   = "k8s-ctrl"
      vb.memory = CTRL_MEM
      vb.cpus   = CTRL_CPUS
    end

    # Networking
    ctrl.vm.network "private_network",
      ip:                "#{cluster_network}.100",
      adapter:           2

    # Provision with Ansible
    ctrl_extra_vars = {
      target: 'ctrl',
      worker_count: NUM_WORKERS,
      cluster_network: cluster_network,
      ctrl_ip: "#{cluster_network}.100"
    }
    ctrl.vm.provision "ansible_local" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "playbooks/general.yaml"
      ansible.extra_vars = ctrl_extra_vars
    end
    ctrl.vm.provision "ansible_local" do |ansible|
      ansible.compatibility_mode = "2.0"
      ansible.playbook = "playbooks/ctrl.yaml"
      ansible.extra_vars = ctrl_extra_vars
    end

  end

  # Defining the worker nodes
  (1..NUM_WORKERS).each do |i|
    config.vm.define "node-#{i}" do |node|
      # General settings
      node.vm.hostname = "k8s-node-#{i}"
      node.vm.provider "virtualbox" do |vb|
        vb.name   = "k8s-node-#{i}"
        vb.memory = WORKER_MEM
        vb.cpus   = WORKER_CPUS
      end

      # Networking
      node.vm.network "private_network",
        ip:                "#{cluster_network}.#{100 + i}",
        adapter:           2

      # Provision with Ansible
      worker_extra_vars = {           
        worker_count: NUM_WORKERS,
        cluster_network: cluster_network,
        ctrl_ip: "#{cluster_network}.#{100 + i}" 
      }
      node.vm.provision "ansible_local" do |ansible|
        ansible.compatibility_mode = "2.0"
        ansible.playbook = "playbooks/general.yaml"
        ansible.extra_vars = worker_extra_vars
      end
      node.vm.provision "ansible_local" do |ansible|
        ansible.compatibility_mode = "2.0"
        ansible.playbook = "playbooks/node.yaml"
        ansible.extra_vars = worker_extra_vars
      end
    end
  end

end

Vagrant.configure("2") do |config|
    workers_count = 2
    ctrl_cpus = 2
    ctrl_mem = 2048
    worker_cpus = 2
    worker_mem = 2048
  
    config.vm.box = "bento/ubuntu-24.04"
  
    # Controller VM
    config.vm.define "ctrl" do |ctrl|
      ctrl.vm.hostname = "k8s-ctrl"
      ctrl.vm.provider "virtualbox" do |vb|
        vb.name   = "k8s-ctrl"
        vb.memory = ctrl_mem
        vb.cpus   = ctrl_cpus
      end
  
      ctrl.vm.network "private_network",
        ip:                "192.168.57.100",
        adapter:           2

      # Ansible inside VM
      ctrl.vm.provision "ansible_local" do |ansible|
        ansible.playbook = "playbooks/general.yaml"
        ansible.extra_vars = { 
          target: 'ctrl',
          worker_count: workers_count,
          cluster_network: "192.168.56",
          ctrl_ip: "192.168.56.100"
        }
      end
      ctrl.vm.provision "ansible_local" do |ansible|
        ansible.playbook = "playbooks/ctrl.yaml"
        ansible.extra_vars = { target: 'ctrl' }
      end
    end
  
    # Worker nodes
    (1..workers_count).each do |i|
      config.vm.define "node-#{i}" do |node|
        node.vm.hostname = "k8s-node-#{i}"
        node.vm.provider "virtualbox" do |vb|
          vb.name   = "k8s-node-#{i}"
          vb.memory = worker_mem
          vb.cpus   = worker_cpus
        end
  
        node.vm.network "private_network",
          ip:                "192.168.57.#{100 + i}",
          adapter:           2

        # Ansible inside VM
        node.vm.provision "ansible_local" do |ansible|
          ansible.playbook = "playbooks/general.yaml"
          ansible.extra_vars = { target: 'node' }
        end
        node.vm.provision "ansible_local" do |ansible|
          ansible.playbook = "playbooks/node.yaml"
          ansible.extra_vars = { 
            join_command: "$JOIN_CMD",
            worker_count: workers_count,
            cluster_network: "192.168.56",
            ctrl_ip: "192.168.56.100"
          }
        end
      end
    end
  end
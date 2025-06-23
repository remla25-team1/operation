# Define VM configurations
NUM_WORKERS = 2
CTRL_CPU = 1
CTRL_MEM = 4*1024
WRK_CPU = 2
WRK_MEM = 6*1024
CL_NETWORK = "192.168.56"
CTRL_PLAYBOOKS = ["playbooks/general.yaml", "playbooks/ctrl.yaml"]
WRK_PLAYBOOKS = ["playbooks/general.yaml", "playbooks/node.yaml"]

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"
   
  # DNS/sudo fix
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    echo "Fixing DNS..."
    rm -f /etc/resolv.conf
    echo "nameserver 8.8.8.8" > /etc/resolv.conf

    echo "vagrant ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vagrant
    chmod 0440 /etc/sudoers.d/vagrant
  SHELL


  # Helper method to configure a VM
  def configure_vm(vm, hostname, ip, cpus, memory, playbooks, extra_vars)
    vm.vm.hostname = hostname
    vm.vm.provider "virtualbox" do |vb|
      vb.name = hostname
      vb.memory = memory
      vb.cpus = cpus
    end
    vm.vm.network "private_network", ip: ip, adapter: 2
    
    playbooks.each do |playbook|
        vm.vm.provision "ansible" do |ansible|
        ansible.verbose = "v"
        ansible.playbook = playbook
        ansible.extra_vars = extra_vars
        ansible.inventory_path = "shared/inventory.ini"
        end
    end
  end

  # Controller VM
  config.vm.define "ctrl" do |ctrl|
    # mount all Vms with shared folder as /mnt/shared
    ctrl.vm.synced_folder "./shared", "/mnt/shared"

    configure_vm(
      ctrl,
      "k8s-ctrl",
      "#{CL_NETWORK}.100",
      CTRL_CPU,
      CTRL_MEM,
      CTRL_PLAYBOOKS,
      {
        target: 'ctrl',
        worker_count: NUM_WORKERS,
        cluster_network: CL_NETWORK,
        ctrl_ip: "#{CL_NETWORK}.100"
      }
    )
  end

  # Worker VMs
  (1..NUM_WORKERS).each do |i|

    config.vm.define "node-#{i}" do |worker|
      # mount all Vms with shared folder as /mnt/shared
      worker.vm.synced_folder "./shared", "/mnt/shared"
      
      configure_vm(
        worker,
        "k8s-node-#{i}",
        "#{CL_NETWORK}.#{100 + i}",
        WRK_CPU,
        WRK_MEM,
        WRK_PLAYBOOKS,
        { target: 'node',
        worker_count: NUM_WORKERS,
        cluster_network: CL_NETWORK,
        ctrl_ip: "#{CL_NETWORK}.100"
    }
    )
    end
  end
end
#! /bin/bash

VMID=200
STORAGE=pool-1

set -x
rm -f noble-server-cloudimg-amd64.img
wget -q https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 8G
sudo qm destroy $VMID
sudo qm create $VMID --name "ubuntu-noble-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
sudo qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
sudo qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
sudo qm set $VMID --boot order=virtio0
sudo qm set $VMID --ide2 $STORAGE:cloudinit

sudo mkdir -p /var/lib/vz/snippets

cat << EOF | sudo tee /var/lib/vz/snippets/ubuntu.yaml
#cloud-config

packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg-agent
  - software-properties-common
  - containerd.io
  - qemu-guest-agent

# Enable ipv4 forwarding, required on CIS hardened machines
write_files:
  - path: /etc/sysctl.d/enabled_ipv4_forwarding.conf
    content: |
      net.ipv4.conf.all.forwarding=1

# create the docker group
groups:
  - docker

# Add default auto created user to docker group
system_info:
  default_user:
    groups: [docker]

runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent
    - snap install docker
    - byobu-enable
    - systemctl enable ssh
    - reboot
    
EOF

sudo qm set $VMID --cicustom "vendor=local:snippets/ubuntu.yaml"
sudo qm set $VMID --tags ubuntu-template,noble,cloudinit
sudo qm set $VMID --ciuser $USER
sudo qm set $VMID --sshkeys ~/.ssh/authorized_keys
sudo qm set $VMID --ipconfig0 ip=dhcp
sudo qm template $VMID

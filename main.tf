terraform {
  required_providers {
    virtualbox = {
      source  = "shekeriev/virtualbox"
      version = "0.0.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5.0"
    }
  }
}

provider "virtualbox" {
  delay      = 60
  mintimeout = 5
}

resource "null_resource" "generate_worker_iso" {
  triggers = {
    ssh_key = fileexists(var.ssh_public_key_path) ? file(var.ssh_public_key_path) : ""
  }

  provisioner "local-exec" {
    command = "python ${path.module}/make_cidata.py --hostname worker --pubkey-file ${var.ssh_public_key_path} --output ${path.module}/seed-worker.iso"
  }
}

resource "null_resource" "generate_db_iso" {
  triggers = {
    ssh_key = fileexists(var.ssh_public_key_path) ? file(var.ssh_public_key_path) : ""
  }

  provisioner "local-exec" {
    command = "python ${path.module}/make_cidata.py --hostname db --pubkey-file ${var.ssh_public_key_path} --output ${path.module}/seed-db.iso"
  }
}

resource "virtualbox_vm" "worker" {
  name          = "worker"
  image         = var.box_url
  cpus          = 1
  memory        = "1024 mib"
  optical_disks = ["${path.module}/seed-worker.iso"]

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    device         = "IntelPro1000MTDesktop"
    host_interface = var.host_interface
  }

  depends_on = [
    null_resource.generate_worker_iso
  ]
}

resource "virtualbox_vm" "db" {
  name          = "db"
  image         = var.box_url
  cpus          = 1
  memory        = "1024 mib"
  optical_disks = ["${path.module}/seed-db.iso"]

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    device         = "IntelPro1000MTDesktop"
    host_interface = var.host_interface
  }

  depends_on = [
    null_resource.generate_db_iso
  ]
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/ansible/inventory.ini"
  content  = <<EOT
[workers]
worker ansible_host=${virtualbox_vm.worker.network_adapter[1].ipv4_address} ansible_user=ansible

[db]
db ansible_host=${virtualbox_vm.db.network_adapter[1].ipv4_address} ansible_user=ansible
EOT
}

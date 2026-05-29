terraform {
  required_providers {
    virtualbox = {
      source  = "shekeriev/virtualbox"
      version = "0.0.4"
    }
  }
}

provider "virtualbox" {
  delay      = 60
  mintimeout = 5
}

resource "virtualbox_vm" "worker" {
  name   = "worker"
  image  = var.box_url
  cpus   = 1
  memory = "1024 mib"

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    device         = "IntelPro1000MTDesktop"
    host_interface = var.host_interface
  }
}

resource "virtualbox_vm" "db" {
  name   = "db"
  image  = var.box_url
  cpus   = 1
  memory = "1024 mib"

  network_adapter {
    type = "nat"
  }

  network_adapter {
    type           = "hostonly"
    device         = "IntelPro1000MTDesktop"
    host_interface = var.host_interface
  }
}

variable "box_url" {
  type        = string
  description = "URL of the Vagrant box image to use"
  default     = "../bento-amd64.box"
}








variable "host_interface" {
  type        = string
  description = "VirtualBox Host-Only Interface name"
  default     = "VirtualBox Host-Only Ethernet Adapter"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the SSH public key for cloud-init"
  default     = "C:/Users/vinim/.ssh/id_ed25519.pub"
}

output "worker_ip" {
  value       = virtualbox_vm.worker.network_adapter[1].ipv4_address
  description = "The Host-Only IP address of the worker VM"
}

output "db_ip" {
  value       = virtualbox_vm.db.network_adapter[1].ipv4_address
  description = "The Host-Only IP address of the db VM"
}

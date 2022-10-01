output "ssh_into_it" {
  value = <<-EOT
  ssh ${equinix_network_ssh_key.this.name}@${equinix_network_device.am.ssh_ip_address} -i ${random_pet.this.id}.pem

  ssh ${equinix_network_ssh_key.this.name}@${equinix_network_device.dc.ssh_ip_address} -i ${random_pet.this.id}.pem
  EOT
}
// for hostname
resource "random_pet" "this" {
  length = 3
}

data "equinix_network_account" "am" {
  metro_code = "AM"
  status     = "Active"
}

data "equinix_network_account" "dc" {
  metro_code = "DC"
}

resource "tls_private_key" "key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "equinix_network_ssh_key" "this" {
  name       = var.username
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${random_pet.this.id}.pem"
  file_permission = "0600"
}

resource "equinix_network_acl_template" "this" {
  name        = "${random_pet.this.id}_allow_all_acl"
  description = "Allow all traffic"
  inbound_rule {
    subnet  = "0.0.0.0/0"
    protocol = "IP"
    src_port = "any"
    dst_port = "any"
    description = "Allow all traffic"
  }
}

resource "equinix_network_device" "am" {
  name            = "${random_pet.this.id}-${data.equinix_network_account.am.metro_code}"
  acl_template_id = equinix_network_acl_template.this.uuid
  self_managed    = true
  byol            = true
  throughput      = 500
  throughput_unit = "Mbps"
  metro_code      = data.equinix_network_account.am.metro_code
  type_code       = var.route_os
  package_code    = "SEC"
  notifications   = var.notification_email
  hostname        = random_pet.this.id
  term_length     = 12
  account_number  = data.equinix_network_account.am.number
  version         = var.route_os_version
  core_count      = 2
  ssh_key {
    username = equinix_network_ssh_key.this.name
    key_name = equinix_network_ssh_key.this.name
  }
  timeouts {
    create = "60m"
    delete = "2h"
  }
}

resource "equinix_network_device" "dc" {
  name            = "${random_pet.this.id}-${data.equinix_network_account.dc.metro_code}"
  acl_template_id = equinix_network_acl_template.this.uuid
  self_managed    = true
  byol            = true  
  throughput      = 500
  throughput_unit = "Mbps"
  metro_code      = data.equinix_network_account.dc.metro_code
  type_code       = var.route_os
  package_code    = "SEC"
  notifications   = var.notification_email
  hostname        = random_pet.this.id
  term_length     = 12
  account_number  = data.equinix_network_account.dc.number
  version         = var.route_os_version
  core_count      = 2
  ssh_key {
    username = equinix_network_ssh_key.this.name
    key_name = equinix_network_ssh_key.this.name
  }
  timeouts {
    create = "60m"
    delete = "2h"
  }
}

resource "equinix_network_device_link" "this" {
  name   = random_pet.this.id
  device {
    id           = equinix_network_device.am.uuid
    asn          = equinix_network_device.am.asn > 0 ? equinix_network_device.am.asn : 65000
    interface_id = 10
  }
  device {
    id           = equinix_network_device.dc.uuid
    asn          = equinix_network_device.dc.asn > 0 ? equinix_network_device.dc.asn : 65001
    interface_id = 9
  }

  link {
    account_number  = equinix_network_device.am.account_number
    src_metro_code  = equinix_network_device.am.metro_code
    dst_metro_code  = equinix_network_device.dc.metro_code
    throughput      = "50"
    throughput_unit = "Mbps"
  }
}
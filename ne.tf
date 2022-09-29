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
  name       = "apopa"
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_sensitive_file" "private_key_pem" {
  content         = tls_private_key.key.private_key_pem
  filename        = "${random_pet.this.id}.pem"
  file_permission = "0600"
}

resource "random_password" "this" {
  length           = 12
  special          = true
  override_special = "@$"
}

resource "equinix_network_ssh_user" "this" {
  username = "apopa"
  password = random_password.this.result
  device_ids = [
    equinix_network_device.am.uuid,
    equinix_network_device.dc.uuid
  ]
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
  type_code       = "CSR1000V"
  package_code    = "SEC"
  notifications   = ["andrei.popa@eu.equinix.com"]
  hostname        = random_pet.this.id
  term_length     = 12
  account_number  = data.equinix_network_account.am.number
  version         = "17.03.03"
  core_count      = 2
  ssh_key {
    username = equinix_network_ssh_key.this.name
    key_name = equinix_network_ssh_key.this.public_key
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
  type_code       = "CSR1000V"
  package_code    = "SEC"
  notifications   = ["andrei.popa@eu.equinix.com"]
  hostname        = random_pet.this.id
  term_length     = 12
  account_number  = data.equinix_network_account.dc.number
  version         = "16.12.03"
  core_count      = 2
  timeouts {
    create = "60m"
    delete = "2h"
  }
}

resource "equinix_network_device_link" "this" {
  name   = random_pet.this.id
  subnet = "192.168.40.64/27"
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
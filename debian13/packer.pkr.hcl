packer {
  required_plugins {
    name = {
      # there's a bug in version 1.2.2 of the plugin, so stick with a version below that for now
      # see https://github.com/hashicorp/packer-plugin-proxmox/issues/307
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "debian_image" {
  type    = string
  default = "debian-13.0.0-amd64-netinst.iso"
}

variable "proxmox_iso_pool" {
  type    = string
  default = "local:iso"
}

variable "proxmox_node" {
  type    = string
  default = ""
}

variable "proxmox_username" {
  type    = string
  default = "${env("PKR_VAR_PROXMOX_USERNAME")}"
}

variable "proxmox_password" {
  type    = string
  default = "${env("PKR_VAR_PROXMOX_PASSWORD")}"
  sensitive = true
}

variable "proxmox_storage_format" {
  type    = string
  default = "raw"
}

variable "proxmox_storage_pool" {
  type    = string
  default = "local-lvm"
}

variable "proxmox_storage_pool_type" {
  type    = string
  default = "lvm-thin"
}

variable "proxmox_url" {
  type    = string
  default = ""
}

variable "template_description" {
  type    = string
  default = "Debian Linux 13 Template"
}

variable "template_name" {
  type    = string
  default = "DEB13-Template"
}

variable "version" {
  type    = string
  default = "q35"
}

source "proxmox-iso" "debian13" {
  vm_id         = 9004
  os            = "l26"
  boot_wait     = "10s"
  boot_command  = [
    "<wait><down>e",
    "<down><down><down><end>",
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "language=en country=DE locale=en_US.UTF-8 keymap=de domain='' ",
    "hostname=debian12 ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian13-preseed.cfg ",
    "--- quiet <wait>",
    "<leftCtrlOn>x<leftCtrlOff>"
  ]
  machine   = "q35"
  cores     = "2"
  cpu_type  = "x86-64-v3"
  bios      = "ovmf"
  efi_config {
      efi_storage_pool  = "${var.proxmox_storage_pool}"
      pre_enrolled_keys = true
  }
  memory    = "2048"
  vga {
    type = "qxl"
  }
  scsi_controller     = "virtio-scsi-single"

  disks {
    type              = "scsi"
    disk_size         = "10G"
    format            = "${var.proxmox_storage_format}"
    storage_pool      = "${var.proxmox_storage_pool}"
  }

  http_directory      = "debian13"

  boot_iso {
    type          = "ide"
    iso_file      = "${var.proxmox_iso_pool}/${var.debian_image}"
    unmount       = true
    iso_checksum  = "none"
  }

  network_adapters {
    bridge    = "vmbr0"
    model     = "virtio"
    firewall  = true
  }

  node                 = "${var.proxmox_node}"

  username             = "${var.proxmox_username}"
  password             = "${var.proxmox_password}"
  proxmox_url          = "${var.proxmox_url}"

  ssh_username         = "root"
  ssh_password         = "Packer"
  ssh_port             = 22
  ssh_timeout          = "30m"

  template_description = "${var.template_description}"
  template_name        = "${var.template_name}"

  cloud_init           = true
  cloud_init_storage_pool = "${var.proxmox_storage_pool}"
}

build {
  sources = ["source.proxmox-iso.debian13"]
  
  name = "proxmox-debian13"

  provisioner "shell" {
    inline = [
      "apt-get update -y",
      "systemctl enable qemu-guest-agent",
      "shred -u /etc/ssh/*_key /etc/ssh/*_key.pub",
      "rm -f /var/run/utmp",
      ">/var/log/lastlog",
      ">/var/log/wtmp",
      ">/var/log/btmp",
      "rm -rf /tmp/* /var/tmp/*",
      "unset HISTFILE; rm -rf /home/*/.*history /root/.*history",
      "rm -f /root/*ks"
    ]
  }

}

# add your credentials here or pass them via env
# export ALICLOUD_ACCESS_KEY="????????????????????"
# export ALICLOUD_SECRET_KEY="????????????????????"
# e.g : ./aliyun-key.sh
provider "alicloud" {
  # access_key = "????????????????????"
  # secret_key = "????????????????????"
}

# use 10.10.10.0/24 cidr block as demo network
resource "alicloud_vpc" "vpc" {
  vpc_name   = "pigsty-demo-network"
  cidr_block = "10.10.10.0/24"
}

# query zones where necessary resources are available
data "alicloud_zones" "zones_ds" {
  available_instance_type = "ecs.n1.small"
  available_resource_creation = "VSwitch"
  # output_file = "zones_ds"
}

# add virtual switch for pigsty demo network
resource "alicloud_vswitch" "vsw" {
  vpc_id     = "${alicloud_vpc.vpc.id}"
  cidr_block = "10.10.10.0/24"
  zone_id    = data.alicloud_zones.zones_ds.zones.0.id
}

# add default security group and allow all tcp traffic
resource "alicloud_security_group" "default" {
  name   = "default"
  vpc_id = "${alicloud_vpc.vpc.id}"
}
resource "alicloud_security_group_rule" "allow_all_tcp" {
  ip_protocol       = "tcp"
  type              = "ingress"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.default.id}"
  cidr_ip           = "0.0.0.0/0"
}

# pg-meta: 1c2G x1
# pg-test: 1c1G x3

# Available IMAGES: https://help.aliyun.com/zh/ecs/user-guide/release-notes-for-2024
# CentOS 7.9     :  centos_7_9_x64_20G_alibase_20240531.vhd
# Rocky 8.9      :  rockylinux_8_9_x64_20G_alibase_20240228.vhd
# Rocky 9.4      :  rockylinux_9_4_x64_20G_alibase_20240531.vhd
# Ubuntu 20.04   :  ubuntu_20_04_x64_20G_alibase_20240530.vhd
# Ubuntu 22.04   :  ubuntu_22_04_x64_20G_alibase_20240530.vhd
# Debian 11.9    :  debian_11_9_x64_20G_alibase_20240531.vhd
# Debian 12.5    :  debian_12_5_x64_20G_alibase_20240531.vhd
# Anolis 8.8     :  anolisos_8_8_x64_20G_rhck_alibase_20240221.vhd

data "alicloud_images" "images_ds" {
  owners     = "system"
  name_regex = "^rockylinux_8_9_x64"    # use rocky 8.9 by default
  #name_regex = "^rockylinux_9_4_x64"    # use rocky 9.4 by default
  #name_regex = "^ubuntu_22_04_x64"      # use ubuntu 22.04 by default
}
# ${data.alicloud_images.images_ds.images.0.id}


# https://registry.terraform.io/providers/aliyun/alicloud/latest/docs/resources/instance
resource "alicloud_instance" "pg-meta-1" {
  instance_name              = "pg-meta-1"
  host_name                  = "pg-meta-1"
  instance_type              = "ecs.n1.small"
  vswitch_id                 = "${alicloud_vswitch.vsw.id}"
  security_groups            = ["${alicloud_security_group.default.id}"]
  image_id                   = "${data.alicloud_images.images_ds.images.0.id}"
  password                   = "PigstyDemo4"
  private_ip                 = "10.10.10.10"
  internet_max_bandwidth_out = 40 # 40Mbps , alloc a public IP
}

resource "alicloud_instance" "pg-test-groups" {
  for_each = toset(["1", "2", "3"])

  instance_name   = "pg-test-${each.key}"
  host_name       = "pg-test-${each.key}"
  private_ip      = "10.10.10.1${each.key}"
  instance_type   = "ecs.n1.tiny"
  vswitch_id      = "${alicloud_vswitch.vsw.id}"
  security_groups = ["${alicloud_security_group.default.id}"]
  image_id        = "${data.alicloud_images.images_ds.images.0.id}"
  password        = "PigstyDemo4"
}

output "admin_ip" {
  value = "${alicloud_instance.pg-meta-1.public_ip}"
}

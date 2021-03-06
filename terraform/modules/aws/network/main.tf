variable "name" {}
variable "vpc_cidr" {}
variable "azs" {}
variable "region" {}
variable "private_subnets" {}
variable "ephemeral_subnets" {}
variable "public_subnets" {}
variable "ssl_cert" {}
variable "ssl_key" {}
variable "key_name" {}
variable "key_file" {}
variable "sub_domain" {}
variable "route_zone_id" {}

variable "bastion_instance_type" {}
variable "nat_instance_type" {}
variable "openvpn_instance_type" {}
variable "openvpn_ami" {}
variable "openvpn_admin_user" {}
variable "openvpn_admin_pw" {}
variable "openvpn_dns_ips" {}
variable "openvpn_cidr" {}

module "vpc" {
  source = "./vpc"

  name = "${var.name}-vpc"
  cidr = "${var.vpc_cidr}"
}

module "public_subnet" {
  source = "./public_subnet"

  name   = "${var.name}-public"
  vpc_id = "${module.vpc.vpc_id}"
  cidrs  = "${var.public_subnets}"
  azs    = "${var.azs}"
}

module "bastion" {
  source = "./bastion"

  name              = "${var.name}-bastion"
  vpc_id            = "${module.vpc.vpc_id}"
  vpc_cidr          = "${module.vpc.vpc_cidr}"
  region            = "${var.region}"
  public_subnet_ids = "${module.public_subnet.subnet_ids}"
  key_name          = "${var.key_name}"
  instance_type     = "${var.bastion_instance_type}"
}

module "nat" {
  source = "./nat"

  name              = "${var.name}-nat"
  vpc_id            = "${module.vpc.vpc_id}"
  vpc_cidr          = "${module.vpc.vpc_cidr}"
  region            = "${var.region}"
  public_subnets    = "${var.public_subnets}"
  public_subnet_ids = "${module.public_subnet.subnet_ids}"
  key_name          = "${var.key_name}"
  key_file          = "${var.key_file}"
  instance_type     = "${var.nat_instance_type}"
  bastion_host      = "${module.bastion.public_ip}"
  bastion_user      = "${module.bastion.user}"
}

module "private_subnet" {
  source = "./private_subnet"

  name   = "${var.name}-private"
  vpc_id = "${module.vpc.vpc_id}"
  cidrs  = "${var.private_subnets}"
  azs    = "${var.azs}"

  nat_instance_ids = "${module.nat.instance_ids}"
}

# The reason for this is that ephemeral nodes (nodes that are recycled often like ASG nodes),
# need to be in separate subnets from long-running nodes (like Elasticache and RDS) because
# AWS maintains an ARP cache with a semi-long expiration time.

# So if node A with IP 10.0.0.123 gets terminated, and node B comes in and picks up 10.0.0.123
# in a relatively short period of time, the stale ARP cache entry will still be there,
# so traffic will just fail to reach the new node.
module "ephemeral_subnets" {
  source = "./private_subnet"

  name   = "${var.name}-ephemeral"
  vpc_id = "${module.vpc.vpc_id}"
  cidrs  = "${var.ephemeral_subnets}"
  azs    = "${var.azs}"

  nat_instance_ids = "${module.nat.instance_ids}"
}

module "openvpn" {
  source = "./openvpn"

  name              = "${var.name}-openvpn"
  vpc_id            = "${module.vpc.vpc_id}"
  vpc_cidr          = "${module.vpc.vpc_cidr}"
  public_subnet_ids = "${module.public_subnet.subnet_ids}"
  ssl_cert          = "${var.ssl_cert}"
  ssl_key           = "${var.ssl_key}"
  key_name          = "${var.key_name}"
  key_file          = "${var.key_file}"
  ami               = "${var.openvpn_ami}"
  instance_type     = "${var.openvpn_instance_type}"
  bastion_host      = "${module.bastion.public_ip}"
  bastion_user      = "${module.bastion.user}"
  admin_user        = "${var.openvpn_admin_user}"
  admin_pw          = "${var.openvpn_admin_pw}"
  dns_ips           = "${var.openvpn_dns_ips}"
  vpn_cidr          = "${var.openvpn_cidr}"
  sub_domain        = "${var.sub_domain}"
  route_zone_id     = "${var.route_zone_id}"
}

resource "aws_network_acl" "acl" {
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = ["${concat(split(",", module.public_subnet.subnet_ids), split(",", module.private_subnet.subnet_ids), split(",", module.ephemeral_subnets.subnet_ids))}"]

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block =  "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags { Name = "${var.name}-all" }
}

# VPC
output "vpc_id"   { value = "${module.vpc.vpc_id}" }
output "vpc_cidr" { value = "${module.vpc.vpc_cidr}" }

# Subnets
output "public_subnet_ids"    { value = "${module.public_subnet.subnet_ids}" }
output "private_subnet_ids"   { value = "${module.private_subnet.subnet_ids}" }
output "ephemeral_subnet_ids" { value = "${module.ephemeral_subnets.subnet_ids}" }

# Bastion
output "bastion_user"       { value = "${module.bastion.user}" }
output "bastion_private_ip" { value = "${module.bastion.private_ip}" }
output "bastion_public_ip"  { value = "${module.bastion.public_ip}" }

# NAT
output "nat_instance_ids" { value = "${module.nat.instance_ids}" }
output "nat_private_ips"  { value = "${module.nat.private_ips}" }
output "nat_public_ips"   { value = "${module.nat.public_ips}" }

# OpenVPN
output "openvpn_private_ip"   { value = "${module.openvpn.private_ip}" }
output "openvpn_public_ip"    { value = "${module.openvpn.public_ip}" }
output "openvpn_public_fqdn"  { value = "${module.openvpn.public_fqdn}" }

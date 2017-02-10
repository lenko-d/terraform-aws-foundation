variable "ami" {
  description = "AMI to use for instances.  Tested with Ubuntu 16.04."
}
variable "instance_type" {
  description = "Type of instance to run the DNS servers"
  default = "t2.nano"
}
variable "subnet_ids" {
  description = "Subnets to run servers in"
  type = "list"
}
variable "private_ips" {
  description = "Private IP addresses of servers, which must be within the subnets specified in 'subnet_ids' (in the same order).  These are specified explicitly since it's desirable to be able to replace a DNS server without its IP address changing.  Our convention is to use the first unreserved address in the subnet (which is to say, the '+4' address)."
  type = "list"
}
variable "security_group_ids" {
  description = "Security groups to assign servers"
  type = "list"
}
variable "key_name" {
  description = "SSH key-pair name to use for setup"
}
variable "name" {
  description = "Name prefix of the servers (will have server number appended)"
  default = "dns"
}
variable "named_conf_options" {
  description = "Complete content of '/etc/bind/named.conf.options'."
}

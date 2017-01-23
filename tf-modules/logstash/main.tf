/**
 *## Logstash
 *
 * This module takes care of deployment of EC2 instances running Logstash using
 * an autoscaling group with a load balancer. It also adds an entry to Route53
 * for the Logstash load balancer. 
 *
 */

resource "aws_elb" "logstash-elb" {
  name            = "${var.name_prefix}-logstash-elb"
  subnets         = ["${var.subnet_ids}"]
  security_groups = ["${aws_security_group.logstash-elb-sg.id}"]
  
  listener {
    instance_port = 5044
    instance_protocol = "tcp"
    lb_port = 5044
    lb_protocol = "tcp"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:5044"
    interval = 30
  }

  cross_zone_load_balancing = true
  idle_timeout = 60
  connection_draining = true
  connection_draining_timeout = 60

  tags {
    Name = "${var.name_prefix}-logstash-elb"
  }

}


resource "aws_route53_record" "logstash-elb" {
  zone_id = "${var.route53_zone_id}"
  name = "${var.logstash_dns_name}"
  type = "A"

  alias {
    name = "${aws_elb.logstash-elb.dns_name}"
    zone_id = "${aws_elb.logstash-elb.zone_id}"
    evaluate_target_health = true
  }
}



data "template_file" "logstash-setup" {
  template = "${file("${path.module}/data/setup.tpl.sh")}"

  vars {
    ca_cert = "${file(var.ca_cert)}"
    server_cert = "${file(var.server_cert)}"
    server_key = "${file(var.server_key)}"
    config = "${data.template_file.logstash-config.rendered}"
    extra_snippet = ""
  }
}

data "template_file" "logstash-config" {
  template = "${file("${path.module}/data/config.tpl.conf")}"

  vars {
    elasticsearch_url = "${var.elasticsearch_url}"
  }
}


resource "aws_security_group" "logstash-sg" {
  name        = "${var.name_prefix}-logstash-sg"
  vpc_id      = "${var.vpc_id}"
  description = "Allow ICMP, SSH, Logstash Beat port (5044) and everything outbound."

  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "logstash-elb-sg" {
  name        = "${var.name_prefix}-logstash-elb-sg"
  vpc_id      = "${var.vpc_id}"
  description = "Allow ICMP, TCP (5044) and everything outbound."

  ingress {
    from_port   = 5044
    to_port     = 5044
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_autoscaling_group" "logstash-asg" {
  count                = "${min(var.max_server_count, 1)}"
  availability_zones   = ["${var.vpc_azs}"]
  vpc_zone_identifier  = ["${var.subnet_ids}"]
  name                 = "${var.name_prefix}-logstash-asg"
  max_size             = "${var.max_server_count}"
  min_size             = "${var.min_server_count}"
  desired_capacity     = "${var.desired_server_count}"
  launch_configuration = "${aws_launch_configuration.logstash-lc.name}"
  health_check_type    = "ELB"
  load_balancers       = ["${aws_elb.logstash-elb.name}"]

  tag = [{
    key                 = "Name"
    value               = "${var.name_prefix}-logstash"
    propagate_at_launch = true
  }]

}


resource "aws_launch_configuration" "logstash-lc" {
  count           = "${min(var.max_server_count, 1)}"
  name_prefix     = "${var.name_prefix}-logstash-lc-"
  image_id        = "${var.ami}"
  instance_type   = "${var.instance_type}"
  key_name        = "${var.key_name}"
  security_groups = ["${aws_security_group.logstash-sg.id}"]
  user_data       = <<USER_DATA
#!/bin/bash
${data.template_file.logstash-setup.rendered}
USER_DATA

  associate_public_ip_address = true

  lifecycle = {
    create_before_destroy = true
  }
  
}



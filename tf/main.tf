provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "GojoVPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "GojoIGW"
  }
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index)
  availability_zone       = element(["us-east-1a", "us-east-1b"], count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "GojoPublicSubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = 4
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index + 2)
  availability_zone = element(["us-east-1a", "us-east-1b", "us-east-1a", "us-east-1b"], count.index)
  tags = {
    Name = "GojoPrivateSubnet-${count.index + 1}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "GojoPublicRT"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "GojoPrivateRT"
  }
}

resource "aws_route_table_association" "private" {
  count          = 4
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GojoWebSG"
  }
}

resource "aws_launch_template" "web" {
  name_prefix   = "web-server-template"
  image_id      = "ami-0427090fd1714168b" # Amazon Linux 2023 AMI
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.web_sg.id]
    subnet_id                   = element(aws_subnet.public.*.id, 0)
  }

  user_data = base64encode(<<-EOF
  #!/bin/bash
    sudo yum update -y
    sudo yum install -y docker
    sudo systemctl start docker
    sudo systemctl enable docker
    sudo usermod -a -G docker ec2-user
    newgrp docker
    docker pull vsramchaik/gojo-web
    docker run -d -p 80:3000 --rm --name web vsramchaik/gojo-web
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "GojoWebServer"
      Tier    = "Web"
      Server  = "WebApp"
      Project = "Gojo"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "GojoWebServer-Volume"
      Tier    = "Web"
      Server  = "WebApp"
      Project = "Gojo"
    }
  }
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "web-server-asg"
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = aws_subnet.public.*.id

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "GojoWebServer"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "Web"
    propagate_at_launch = true
  }

  tag {
    key                 = "Server"
    value               = "WebApp"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Gojo"
    propagate_at_launch = true
  }
}

resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = aws_subnet.public.*.id

  tags = {
    Name    = "GojoWebLB"
    Tier    = "Web"
    Server  = "WebApp"
    Project = "Gojo"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/login"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name    = "GojoWebTG"
    Tier    = "Web"
    Server  = "WebApp"
    Project = "Gojo"
  }
}

resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
  lb_target_group_arn    = aws_lb_target_group.web_tg.arn
}

resource "aws_cloudwatch_metric_alarm" "high_network_in" {
  alarm_name          = "high-network-in"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5000000" # 5 MB in bytes
  alarm_description   = "This metric monitors EC2 network in utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_cloudwatch_metric_alarm" "low_network_in" {
  alarm_name          = "low-network-in"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000000" # 1 MB in bytes
  alarm_description   = "This metric monitors EC2 network in utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web_asg.name
  }
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web_asg.name
}

resource "aws_wafv2_web_acl" "web_acl" {
  name        = "GojoWebACL"
  description = "WAF for Gojo Web Application"
  scope       = "REGIONAL"
  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "GojoWebACL"
    sampled_requests_enabled   = true
  }

  tags = {
    Name    = "GojoWebACL"
    Tier    = "Web"
    Server  = "WebApp"
    Project = "Gojo"
  }
}

resource "aws_wafv2_web_acl_association" "web_acl_association" {
  resource_arn = aws_lb.web_lb.arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}

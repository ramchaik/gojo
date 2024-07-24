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
    Name = "GojoInternetGateway"
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
  availability_zone = element(["us-east-1a", "us-east-1b"], count.index % 2)
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
    Name = "GojoPublicRouteTable"
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
    Name = "GojoPrivateRouteTable"
  }
}

resource "aws_route_table_association" "private" {
  count          = 4
  subnet_id      = element(aws_subnet.private.*.id, count.index)
  route_table_id = aws_route_table.private.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "GojoNATGatewayEIP"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "GojoNATGateway"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Update the private route table to use the NAT Gateway
resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# NACL for public subnets
resource "aws_network_acl" "public" {
  vpc_id = aws_vpc.main.id

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 130
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "GojoPublicNACL"
  }
}

# Associate public NACL with public subnets
resource "aws_network_acl_association" "public" {
  count          = 2
  network_acl_id = aws_network_acl.public.id
  subnet_id      = aws_subnet.public[count.index].id
}

# NACL for private subnets
resource "aws_network_acl" "private" {
  vpc_id = aws_vpc.main.id

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = aws_vpc.main.cidr_block
    from_port  = 0
    to_port    = 65535
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "GojoPrivateNACL"
  }
}

# Associate private NACL with private subnets
resource "aws_network_acl_association" "private" {
  count          = 4
  network_acl_id = aws_network_acl.private.id
  subnet_id      = aws_subnet.private[count.index].id
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
  docker run -d -p 80:3000 --rm --name web \
    -e COOKIE_SECRET="gojoiscool" \
    -e LIVEBLOCKS_SECRET_KEY="${var.liveblocks_secret}" \
    -e BACKEND_API_BASE_URL="http://${aws_lb.app_lb.dns_name}/api/v1" \
    vsramchaik/gojo-web
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
  desired_capacity    = 2
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

  depends_on = [aws_autoscaling_group.app_asg]
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

  depends_on = [aws_lb.app_lb]
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

resource "aws_cloudwatch_metric_alarm" "high_network_in_web" {
  alarm_name          = "high-network-in-web"
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

resource "aws_cloudwatch_metric_alarm" "low_network_in_web" {
  alarm_name          = "low-network-in-web"
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

resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GojoAppSG"
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "app-server-template"
  image_id      = "ami-0427090fd1714168b" # Amazon Linux 2023 AMI
  instance_type = "t3.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app_sg.id]
    subnet_id                   = element(aws_subnet.private.*.id, 0)
  }

  user_data = base64encode(<<-EOF
  #!/bin/bash
  sudo yum update -y
  sudo yum install -y docker
  sudo systemctl start docker
  sudo systemctl enable docker
  sudo usermod -a -G docker ec2-user
  newgrp docker
  docker pull vsramchaik/gojo-api
  docker run -d -p 80:9000 --rm --name api \
    -e DATABASE_URL="postgres://${var.db_username}:${var.db_password}@${aws_db_instance.gojo_db.endpoint}/${aws_db_instance.gojo_db.db_name}" \
    -e PORT=9000 \
    vsramchaik/gojo-api
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "GojoAppServer"
      Tier    = "Apppplication"
      Server  = "AppService"
      Project = "Gojo"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name    = "GojoAppServer-Volume"
      Tier    = "App"
      Server  = "AppService"
      Project = "Gojo"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name                = "app-server-asg"
  desired_capacity    = 1
  max_size            = 3
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.private[0].id, aws_subnet.private[1].id]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "GojoAppServer"
    propagate_at_launch = true
  }

  tag {
    key                 = "Tier"
    value               = "App"
    propagate_at_launch = true
  }

  tag {
    key                 = "Server"
    value               = "AppService"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = "Gojo"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_attachment" "app_asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
  lb_target_group_arn    = aws_lb_target_group.app_tg.arn
}

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.private[0].id, aws_subnet.private[1].id]

  tags = {
    Name = "GojoAppLB"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.app_tg.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name    = "GojoAppTG"
    Tier    = "App"
    Server  = "AppService"
    Project = "Gojo"
  }
}


resource "aws_cloudwatch_metric_alarm" "high_network_in_app" {
  alarm_name          = "high-network-in-app"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "5000000" # 5 MB in bytes
  alarm_description   = "This metric monitors EC2 network in utilization"
  alarm_actions       = [aws_autoscaling_policy.app_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_autoscaling_policy" "app_scale_up" {
  name                   = "scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_cloudwatch_metric_alarm" "low_network_in_app" {
  alarm_name          = "low-network-in-app"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000000" # 1 MB in bytes
  alarm_description   = "This metric monitors EC2 network in utilization"
  alarm_actions       = [aws_autoscaling_policy.app_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.app_asg.name
  }
}

resource "aws_autoscaling_policy" "app_scale_down" {
  name                   = "scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.app_asg.name
}

resource "aws_db_instance" "gojo_db" {
  identifier             = "gojo-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.5"
  instance_class         = "db.t3.micro"
  db_name                = "gojo"
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres15"
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.gojo_db_subnet_group.name

  tags = {
    Name    = "GojoDB"
    Tier    = "Data"
    Service = "GojoRDSDatabase"
    Project = "Gojo"
  }
}

resource "aws_security_group" "db_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "GojoDBSG"
  }
}

resource "aws_db_subnet_group" "gojo_db_subnet_group" {
  name       = "gojo-db-subnet-group"
  subnet_ids = [aws_subnet.private[2].id, aws_subnet.private[3].id]

  tags = {
    Name = "GojoDBSubnetGroup"
  }
}

resource "aws_cloudwatch_metric_alarm" "high_cpu_db" {
  alarm_name          = "high-cpu-db"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "80" # 80% CPU utilization
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.db_alarm.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.gojo_db.identifier
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu_db" {
  alarm_name          = "low-cpu-db"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "60"
  statistic           = "Average"
  threshold           = "10" # 10% CPU utilization
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.db_alarm.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.gojo_db.identifier
  }
}

resource "aws_sns_topic" "db_alarm" {
  name         = "db-alarm-topic"
  display_name = "RDS Alarms"
}

resource "aws_sns_topic_subscription" "db_alarm_subscription" {
  topic_arn = aws_sns_topic.db_alarm.arn
  protocol  = "email"
  endpoint  = "vaibhav.singh@dal.ca"
}
# TODO: 
# 1. Add rds proxy
# 2. Add Buggets for the project > send alerts for different threshold

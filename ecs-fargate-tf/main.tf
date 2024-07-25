provider "aws" {
  region = "us-east-1"
}

# VPC and Networking
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
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "GojoPrivateRouteTable"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

# NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "GojoNATGatewayEIP"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "GojoNATGateway"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route" "private_nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
}

# Security Groups
resource "aws_security_group" "web_lb_sg" {
  vpc_id = aws_vpc.main.id
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
    Name = "GojoWebLBSG"
  }
}

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port   = 3000
    to_port     = 3000
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

resource "aws_security_group" "app_lb_sg" {
  vpc_id = aws_vpc.main.id
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
    Name = "GojoAppLBSG"
  }
}

resource "aws_security_group" "app_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 9000
    to_port         = 9000
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
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

# Load Balancers
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_lb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name    = "GojoWebLB"
    Tier    = "Web"
    Project = "Gojo"
  }
}

resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

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

resource "aws_lb" "app_lb" {
  name               = "app-lb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_lb_sg.id]
  subnets            = [aws_subnet.private[1].id, aws_subnet.private[2].id]

  tags = {
    Name    = "GojoAppLB"
    Tier    = "App"
    Project = "Gojo"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg"
  port        = 9000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

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
    Project = "Gojo"
  }
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}


# ECS Clusters
resource "aws_ecs_cluster" "web_cluster" {
  name = "gojo-web-cluster"
  tags = {
    Name    = "GojoWebCluster"
    Tier    = "Web"
    Project = "Gojo"
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "gojo-app-cluster"
  tags = {
    Name    = "GojoAppCluster"
    Tier    = "App"
    Project = "Gojo"
  }
}

# ECS Task Definitions
resource "aws_ecs_task_definition" "web_task" {
  family                   = "gojo-web-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::714922497054:role/LabRole"
  container_definitions = jsonencode([
    {
      name  = "web"
      image = "vsramchaik/gojo-web:latest"
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "COOKIE_SECRET"
          value = "gojoiscool"
        },
        {
          name  = "LIVEBLOCKS_SECRET_KEY"
          value = var.liveblocks_secret
        },
        {
          name  = "BACKEND_API_BASE_URL"
          value = "http://${aws_lb.app_lb.dns_name}/api/v1"
        }
      ]
    }
  ])
  tags = {
    Name    = "GojoWebTask"
    Tier    = "Web"
    Project = "Gojo"
  }
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "gojo-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = "arn:aws:iam::714922497054:role/LabRole"
  container_definitions = jsonencode([
    {
      name  = "api"
      image = "vsramchaik/gojo-api:latest"
      portMappings = [
        {
          containerPort = 9000
          hostPort      = 9000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "DATABASE_URL"
          value = "postgres://${var.db_username}:${var.db_password}@${aws_db_proxy.gojo_db_proxy.endpoint}/${aws_db_instance.gojo_db.db_name}"
        },
        {
          name  = "PORT"
          value = "9000"
        }
      ]
    }
  ])
  tags = {
    Name    = "GojoAppTask"
    Tier    = "App"
    Project = "Gojo"
  }
}

# ECS Services
resource "aws_ecs_service" "web_service" {
  name            = "gojo-web-service"
  cluster         = aws_ecs_cluster.web_cluster.id
  task_definition = aws_ecs_task_definition.web_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.web_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web_tg.arn
    container_name   = "web"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.web_listener,
    aws_ecs_task_definition.web_task
  ]

  tags = {
    Name    = "GojoWebService"
    Tier    = "Web"
    Project = "Gojo"
  }
}

resource "aws_ecs_service" "app_service" {
  name            = "gojo-app-service"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.app_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "api"
    container_port   = 9000
  }

  depends_on = [
    aws_lb_listener.app_listener,
    aws_ecs_task_definition.app_task
  ]

  tags = {
    Name    = "GojoAppService"
    Tier    = "App"
    Project = "Gojo"
  }
}

# Auto Scaling for ECS Services
resource "aws_appautoscaling_target" "web_service_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.web_cluster.name}/${aws_ecs_service.web_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Web service scale-out policy based on memory utilization
resource "aws_appautoscaling_policy" "web_service_memory" {
  name               = "web-service-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.web_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0 # Target 80% memory utilization
  }
}

# Web service scale-out policy based on CPU utilization
resource "aws_appautoscaling_policy" "web_service_cpu" {
  name               = "web-service-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.web_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.web_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0 # Target 70% CPU utilization
  }
}

# Web service scale-in policy
resource "aws_appautoscaling_policy" "web_service_scale_in" {
  name               = "web-service-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.web_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.web_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.web_service_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}


resource "aws_appautoscaling_target" "app_service_target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.app_cluster.name}/${aws_ecs_service.app_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# App service scale-out policy based on memory utilization
resource "aws_appautoscaling_policy" "web_service_memory" {
  name               = "app-service-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.app_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = 80.0 # Target 80% memory utilization
  }
}

# App service scale-out policy based on CPU
resource "aws_appautoscaling_policy" "app_service_cpu" {
  name               = "app-service-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.app_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.app_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_service_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# App service scale-in policy
resource "aws_appautoscaling_policy" "app_service_scale_in" {
  name               = "app-service-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.app_service_target.resource_id
  scalable_dimension = aws_appautoscaling_target.app_service_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.app_service_target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

# IAM roles and instance profile for ECS
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# Create an instance profile using the existing role
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs-instance-profile"
  role = data.aws_iam_role.lab_role.name
}

# RDS Proxy
resource "aws_db_proxy" "gojo_db_proxy" {
  name                   = "gojo-db-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = true
  role_arn               = data.aws_iam_role.lab_role.arn
  vpc_security_group_ids = [aws_security_group.db_proxy_sg.id]
  vpc_subnet_ids         = [aws_subnet.private[2].id, aws_subnet.private[3].id]

  auth {
    auth_scheme = "SECRETS"
    iam_auth    = "DISABLED"
    secret_arn  = aws_secretsmanager_secret.db_credentials.arn
  }

  tags = {
    Name    = "GojoDBProxy"
    Tier    = "Data"
    Service = "GojoRDSProxy"
    Project = "Gojo"
  }
}

resource "aws_db_proxy_default_target_group" "gojo_db_proxy_target_group" {
  db_proxy_name = aws_db_proxy.gojo_db_proxy.name

  connection_pool_config {
    max_connections_percent = 100
  }
}

resource "aws_db_proxy_target" "gojo_db_proxy_target" {
  db_instance_identifier = aws_db_instance.gojo_db.identifier
  db_proxy_name          = aws_db_proxy.gojo_db_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.gojo_db_proxy_target_group.name
}

# Security group for RDS Proxy
resource "aws_security_group" "db_proxy_sg" {
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
    Name = "GojoDBProxySG"
  }
}

# Store DB credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "gojo-db-credentials"
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# RDS Instance
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

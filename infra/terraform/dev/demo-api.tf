# This public HTTPS entry point is intentionally opt-in. Set enable_demo_api=true
# only while preparing or running a demo, then set it back to false and apply.
resource "aws_security_group" "api_vpc_link" {
  count       = var.enable_demo_api ? 1 : 0
  name        = "${var.project_name}-${var.environment}-api-vpc-link-sg"
  description = "VPC Link traffic to the internal APTraining demo ALB"
  vpc_id      = aws_vpc.aptraining.id

  egress {
    description     = "HTTP to the internal demo ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api-vpc-link-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_api_vpc_link" {
  count                        = var.enable_demo_api ? 1 : 0
  security_group_id            = aws_security_group.alb.id
  description                  = "HTTP from the API Gateway VPC Link"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.api_vpc_link[0].id
}

resource "aws_lb" "demo_api" {
  count              = var.enable_demo_api ? 1 : 0
  name               = "${var.project_name}-${var.environment}-api"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets = [
    aws_subnet.aptraining["app_a"].id,
    aws_subnet.aptraining["app_b"].id,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-demo-api"
  }
}

resource "aws_lb_target_group" "backend" {
  count       = var.enable_demo_api ? 1 : 0
  name        = "${var.project_name}-${var.environment}-backend"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.aptraining.id

  health_check {
    enabled             = true
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-backend"
  }
}

resource "aws_lb_listener" "demo_api_http" {
  count             = var.enable_demo_api ? 1 : 0
  load_balancer_arn = aws_lb.demo_api[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend[0].arn
  }
}

resource "aws_ecs_service" "backend_demo" {
  count           = var.enable_demo_api ? 1 : 0
  name            = "${var.project_name}-${var.environment}-backend-demo"
  cluster         = aws_ecs_cluster.dev.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100
  health_check_grace_period_seconds  = 180

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      aws_subnet.aptraining["app_a"].id,
      aws_subnet.aptraining["app_b"].id,
    ]
    security_groups  = [aws_security_group.app.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend[0].arn
    container_name   = "backend"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.demo_api_http]
}

resource "aws_apigatewayv2_api" "demo" {
  count         = var.enable_demo_api ? 1 : 0
  name          = "${var.project_name}-${var.environment}-demo-api"
  protocol_type = "HTTP"
  description   = "On-demand HTTPS endpoint for APTraining dev demos"
}

resource "aws_apigatewayv2_vpc_link" "demo" {
  count              = var.enable_demo_api ? 1 : 0
  name               = "${var.project_name}-${var.environment}-demo"
  security_group_ids = [aws_security_group.api_vpc_link[0].id]
  subnet_ids = [
    aws_subnet.aptraining["app_a"].id,
    aws_subnet.aptraining["app_b"].id,
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-demo"
  }
}

resource "aws_apigatewayv2_integration" "backend" {
  count                  = var.enable_demo_api ? 1 : 0
  api_id                 = aws_apigatewayv2_api.demo[0].id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.demo_api_http[0].arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.demo[0].id
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000
}

resource "aws_apigatewayv2_route" "backend" {
  count     = var.enable_demo_api ? 1 : 0
  api_id    = aws_apigatewayv2_api.demo[0].id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.backend[0].id}"
}

resource "aws_apigatewayv2_stage" "demo" {
  count       = var.enable_demo_api ? 1 : 0
  api_id      = aws_apigatewayv2_api.demo[0].id
  name        = "$default"
  auto_deploy = true
}

output "demo_api_url" {
  description = "AWS-managed HTTPS URL for the on-demand APTraining dev demo API"
  value       = var.enable_demo_api ? aws_apigatewayv2_api.demo[0].api_endpoint : null
}

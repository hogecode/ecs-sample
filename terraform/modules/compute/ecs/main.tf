# ECS Module - Using terraform-aws-modules

# ========================================
# ECR Repositories are managed in terraform/modules/compute/ecr/
# ========================================
# Note: ECR repositories are centrally managed in the ecr module
# to avoid duplication and keep separation of concerns clear.

# ========================================
# CloudWatch Log Groups
# ========================================

resource "aws_cloudwatch_log_group" "nextjs" {
  name              = "/ecs/${var.project_name}-nextjs-${var.environment}"
  retention_in_days = var.logs_retention_days
  tags = {
    Name = "${var.project_name}-nextjs-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "go_server" {
  name              = "/ecs/${var.project_name}-go-server-${var.environment}"
  retention_in_days = var.logs_retention_days
  tags = {
    Name = "${var.project_name}-go-server-logs-${var.environment}"
  }
}

resource "aws_cloudwatch_log_group" "xray" {
  name              = "/ecs/${var.project_name}-xray-${var.environment}"
  retention_in_days = var.logs_retention_days
  tags = {
    Name = "${var.project_name}-xray-logs-${var.environment}"
  }
}

# ========================================
# ECS Cluster (using terraform-aws-modules)
# ========================================

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws"
  version = "~> 5.0"

  cluster_name = "${var.project_name}-cluster-${var.environment}"

  # Container Insights
  cluster_settings = {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = {
    Name = "${var.project_name}-cluster-${var.environment}"
  }
}

# ========================================
# IAM Roles for ECS
# ========================================

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role-${var.environment}"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "ecs_task_execution_custom" {
  name = "${var.project_name}-ecs-task-execution-custom-${var.environment}"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

# Next.js Task Role
resource "aws_iam_role" "ecs_task_role_nextjs" {
  name = "${var.project_name}-ecs-task-role-nextjs-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role-nextjs-${var.environment}"
  }
}

resource "aws_iam_role_policy" "ecs_task_role_nextjs" {
  name = "${var.project_name}-ecs-task-role-nextjs-policy-${var.environment}"
  role = aws_iam_role.ecs_task_role_nextjs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-nextjs-*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      }
    ]
  })
}

# Go Server Task Role
resource "aws_iam_role" "ecs_task_role_go_server" {
  name = "${var.project_name}-ecs-task-role-go-server-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-ecs-task-role-go-server-${var.environment}"
  }
}

resource "aws_iam_role_policy" "ecs_task_role_go_server" {
  name = "${var.project_name}-ecs-task-role-go-server-policy-${var.environment}"
  role = aws_iam_role.ecs_task_role_go_server.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-go-server-*"
      },
      {
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.project_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances", "rds-db:connect"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData", "kms:Decrypt"]
        Resource = "*"
      }
    ]
  })
}

# ========================================
# ECS Task Definitions
# ========================================

# Next.js Task Definition
resource "aws_ecs_task_definition" "nextjs" {
  family                   = "${var.project_name}-nextjs"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.nextjs_task_cpu
  memory                   = var.nextjs_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role_nextjs.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-nextjs"
      image     = "${var.ecr_nextjs_repository_url}:${var.nextjs_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.nextjs_container_port
          hostPort      = var.nextjs_container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.nextjs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = var.nextjs_environment_variables
      secrets     = var.nextjs_secrets
    }
  ])

  tags = {
    Name = "${var.project_name}-nextjs-task-${var.environment}"
  }
}

# Go Server Task Definition
resource "aws_ecs_task_definition" "go_server" {
  family                   = "${var.project_name}-go-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.go_server_task_cpu
  memory                   = var.go_server_task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role_go_server.arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-go-server"
      image     = "${var.ecr_go_server_repository_url}:${var.go_server_image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = var.go_server_container_port
          hostPort      = var.go_server_container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.go_server.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = var.go_server_environment_variables
      secrets     = var.go_server_secrets
    }
  ])

  tags = {
    Name = "${var.project_name}-go-server-task-${var.environment}"
  }
}

# ========================================
# ECS Services
# ========================================

# Next.js Service
resource "aws_ecs_service" "nextjs" {
  name            = "${var.project_name}-nextjs-service"
  cluster         = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.nextjs.arn
  desired_count   = var.nextjs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_app_subnet_ids
    security_groups  = [var.nextjs_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.nextjs_target_group_arn
    container_name   = "${var.project_name}-nextjs"
    container_port   = var.nextjs_container_port
  }

  depends_on = [
    aws_iam_role_policy.ecs_task_execution_custom,
    aws_iam_role_policy.ecs_task_role_nextjs
  ]

  tags = {
    Name = "${var.project_name}-nextjs-service-${var.environment}"
  }
}

# Go Server Service
resource "aws_ecs_service" "go_server" {
  name            = "${var.project_name}-go-server-service"
  cluster         = module.ecs_cluster.cluster_id
  task_definition = aws_ecs_task_definition.go_server.arn
  desired_count   = var.go_server_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_api_subnet_ids
    security_groups  = [var.go_server_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.go_server_target_group_arn
    container_name   = "${var.project_name}-go-server"
    container_port   = var.go_server_container_port
  }

  depends_on = [
    aws_iam_role_policy.ecs_task_execution_custom,
    aws_iam_role_policy.ecs_task_role_go_server
  ]

  tags = {
    Name = "${var.project_name}-go-server-service-${var.environment}"
  }
}

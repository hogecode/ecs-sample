# ALB Module - Direct AWS resources for flexibility

# ========================================
# Public ALB for Next.js frontend
# ========================================

resource "aws_lb" "public" {
  name               = "${var.project_name}-public-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_public_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection       = var.environment == "prod" ? true : false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-public-alb-${var.environment}"
  }
}

resource "aws_lb_target_group" "nextjs" {
  name        = "${var.project_name}-nextjs-tg-${var.environment}"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  tags = {
    Name = "${var.project_name}-nextjs-tg-${var.environment}"
  }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "target_group_arn" {
      for_each = var.enable_https ? [] : [aws_lb_target_group.nextjs.arn]
      content {
        target_group_arn = target_group_arn.value
      }
    }
  }
}

resource "aws_lb_listener" "public_https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.public.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.alb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nextjs.arn
  }
}

# ========================================
# Private ALB for Go Server backend
# ========================================

resource "aws_lb" "private" {
  name               = "${var.project_name}-private-alb-${var.environment}"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.private_alb_security_group_id]
  subnets            = var.private_api_subnet_ids

  enable_deletion_protection       = var.environment == "prod" ? true : false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-private-alb-${var.environment}"
  }
}

resource "aws_lb_target_group" "go_server" {
  name        = "${var.project_name}-go-server-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200-399"
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = true
    cookie_duration = 86400
  }

  tags = {
    Name = "${var.project_name}-go-server-tg-${var.environment}"
  }
}

resource "aws_lb_listener" "private_http" {
  load_balancer_arn = aws_lb.private.arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.go_server.arn
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    "Name" = "main"
    "Provider" = "terraform"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.vpc_public_subnets)
  cidr_block              = element(var.vpc_public_subnets, count.index)
  availability_zone       = element(var.vpc_azs, count.index)
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.main.id

  tags = {
    "Provider" = "terraform"
    "Name"      = format("public-%d", count.index)
    "Tier"      = "public"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.vpc_private_subnets)
  cidr_block        = element(var.vpc_private_subnets, count.index)
  availability_zone = element(var.vpc_azs, count.index)
  vpc_id            = aws_vpc.main.id

  tags = {
    "Provider" = "terraform"
    "Name"      = format("private-%d", count.index)
    "Tier"      = "private"
  }
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Provider" = "terraform"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Provider" = "terraform"
    "Name"      = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    "Provider" = "terraform"
    "Name"      = "public"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = element(aws_subnet.private, count.index).id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = element(aws_subnet.public, count.index).id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "shared-alb-sg" {
  name   = "shared-alb-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
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
    "Provider" = "terraform"
    "Name"     = "shared-alb-sg"
  }
}

resource "aws_lb" "shared-alb" {
  name               = "shared-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.shared-alb-sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
}

resource "aws_lb_target_group" "tg" {
  count = length(var.applications)

  port     = var.applications[index].port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  tags = {
    "Provider"   = "terraform"
    "Environment" = var.applications[count.index].environment
    "Name" = format(
    "%s-%s-%s",
      var.applications[count.index].name,
      var.applications[count.index].type,
      var.applications[count.index].environment
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.shared-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = [
      for index, app in var.applications : aws_lb_target_group.tg[index].arn
      if app.url_path == "/"
    ][0]
  }

  tags = {
    "Provider" = "terraform"
  }
}

resource "aws_lb_listener_rule" "rule" {
  for_each = {
    for index, tg in aws_lb_target_group.tg : index => tg if tg.tags_all.Name != format(
      "%s-%s-%s",
      [for app in var.applications : app.name if app.url_path == "/"][0],
      [for app in var.applications : app.type if app.url_path == "/"][0],
      [for app in var.applications : app.environment if app.url_path == "/"][0]
    )
  }

  listener_arn = aws_lb_listener.listener.arn

  action {
    type             = "forward"
    target_group_arn = each.value.arn
  }

  condition {
    path_pattern {
      values = [
        for app in var.applications : app.url_path
        if each.value.tags_all.Name == format(
          "%s-%s-%s",
          app.name,
          app.type,
          app.environment
        )
      ]
    }
  }

  tags = {
    "Provider" = "terraform"
  }
}

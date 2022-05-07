output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "alb_arn" {
  value = aws_lb.shared-alb.arn
}

output "target_groups" {
  value = [
    for index, app in var.applications : {
      application_name = format("%s-%s", app.name, app.type)
      arn = aws_lb_target_group.tg[index].arn
    }
  ]
}
 
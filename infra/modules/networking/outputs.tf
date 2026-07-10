output "private_subnet_1a_id" {
  value = aws_subnet.private_1a.id
}

output "sg_qdrant_id" {
  value = aws_security_group.qdrant.id
}

output "sg_worker_id" {
  value = aws_security_group.worker.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_1a_id" {
  value = aws_subnet.public_1a.id
}

output "public_subnet_1b_id" {
  value = aws_subnet.public_1b.id
}

output "sg_ecs_id" {
  value = aws_security_group.ecs.id
}

output "sg_alb_id" {
  value = aws_security_group.alb.id
}
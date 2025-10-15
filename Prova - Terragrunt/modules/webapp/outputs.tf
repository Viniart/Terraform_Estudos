# modules/webapp/outputs.tf

output "alb_dns_name" {
  description = "O endereço DNS do Application Load Balancer."
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "O endereço (endpoint) do banco de dados RDS."
  value       = aws_db_instance.main.endpoint
}
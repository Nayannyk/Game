output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.game_alb.dns_name
}

output "service_url" {
  description = "Full URL to access the game"
  value       = "http://${aws_lb.game_alb.dns_name}/game.html"
}

output "ecs_cluster_name" {
  description = "ECS Cluster name"
  value       = aws_ecs_cluster.game_cluster.name
}

output "ecs_service_name" {
  description = "ECS Service name"
  value       = aws_ecs_service.game_service.name
}

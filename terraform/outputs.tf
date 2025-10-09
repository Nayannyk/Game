output "load_balancer_dns" {
  value = aws_lb.game_alb.dns_name
  description = "The DNS name of the load balancer"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.game_repo.repository_url
}

output "service_url" {
  description = "Full URL to access the game"
  value       = "http://${aws_lb.game_alb.dns_name}/game.html"
}

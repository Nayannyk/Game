variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "ecr_repository" {
  description = "ECR repository name"
  type        = string
  default     = "game-app"
}

variable "ecr_image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}
variable "aws_account_id" {
  description = "Your AWS Account ID"
  type        = string
  default     = "127898337602"  # MANUAL ENTRY REQUIRED - Replace with your AWS Account ID
}

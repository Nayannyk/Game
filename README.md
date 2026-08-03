# Snake Game

A simple browser-based Snake game that is containerized and deployed to AWS ECS (Fargate) behind an Application Load Balancer. The full CI/CD pipeline is automated with Jenkins and the infrastructure is provisioned using Terraform.

## Table of Contents

- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [How to Play](#how-to-play)
- [Tech Stack](#tech-stack)
- [Local Development](#local-development)
- [Infrastructure](#infrastructure)
- [CI/CD Pipeline](#cicd-pipeline)
- [Deployment URL](#deployment-url)

## Architecture

```
+----------------+     +----------------+     +---------------------+
|  Jenkins       | --> |  ECR           | --> |  ECS Cluster        |
|  CI/CD         |     |  Repository    |     |  (Fargate, 2 tasks) |
+----------------+     +----------------+     +---------------------+
                                                       |
                                                       v
                                              +---------------------+
                                              |  ALB                |
                                              |  (Load Balancer)    |
                                              +---------------------+
                                                       |
                                                       v
                                              http://<ALB-DNS>/game.html
```

1. Jenkins pulls the code from the GitHub repository.
2. Terraform provisions the ECR repository and AWS infrastructure.
3. The Docker image is built and pushed to ECR.
4. Terraform deploys the ECS service (Fargate) with the image.
5. The Application Load Balancer distributes traffic across the ECS tasks.
6. The game is accessible at the ALB DNS.

## Project Structure

```
.
├── game.html               # The Snake game (single-file HTML/JS/CSS app)
├── Dockerfile              # Nginx-based container that serves the game
├── Jenkinsfile             # CI/CD pipeline definition
├── terraform/
│   ├── main.tf             # Core infrastructure (VPC, ECS, ECR, ALB, IAM)
│   ├── outputs.tf          # Useful output values (e.g. load balancer DNS)
│   └── variables.tf        # Input variables
└── .gitignore
```

## How to Play

- Open `game.html` in any modern web browser.
- Click **Start Game** to begin.
- Use the **Arrow Keys** or **WASD** to control the snake.
- Eat the red food to grow and earn **10 points** per food.
- Avoid hitting the walls or your own body — the game ends on collision.
- Your high score is saved in the browser's local storage.

## Tech Stack

| Layer          | Technology                                    |
|----------------|-----------------------------------------------|
| Frontend       | HTML, CSS, Vanilla JavaScript (Canvas API)    |
| Container      | Docker, Nginx (alpine)                        |
| CI/CD          | Jenkins Pipeline                              |
| IaC            | Terraform (AWS provider ~> 4.0)               |
| Compute        | AWS ECS with Fargate                          |
| Load Balancing | AWS Application Load Balancer                 |
| Image Registry | AWS ECR                                       |
| Region         | ap-south-1 (Mumbai)                           |

## Local Development

To run the game locally, you can either:

**Option 1 - Open directly in browser:**

```bash
start game.html
```

**Option 2 - Run with Docker:**

```bash
docker build -t snake-game .
docker run -p 8080:80 snake-game
# Open http://localhost:8080/game.html
```

## Infrastructure

The Terraform configuration in the `terraform/` directory provisions:

- **ECR** - Docker image repository (`game-app`)
- **VPC** - Custom VPC (`10.0.0.0/16`) with public and private subnets
- **ECS** - Cluster, Fargate task definition, and service (2 tasks, 256 CPU / 512 MB)
- **ALB** - Application Load Balancer routing traffic to the ECS tasks
- **CloudWatch** - Log group for ECS container logs
- **IAM** - Task execution role for ECS
- **Security Groups** - Scoped to allow HTTP traffic from the ALB only

### Key Variables

| Variable          | Default       | Description              |
|-------------------|---------------|--------------------------|
| `aws_region`      | `ap-south-1`  | AWS region               |
| `ecr_repository`  | `game-app`    | ECR repository name      |
| `ecr_image_tag`   | `latest`      | Docker image tag         |
| `aws_account_id`  | *(required)*  | AWS account ID           |

### Useful Outputs

- `load_balancer_dns` - DNS name of the load balancer
- `ecr_repository_url` - ECR repository URL
- `service_url` - Full URL to access the game (`http://<ALB-DNS>/game.html`)

## CI/CD Pipeline

The `Jenkinsfile` defines the following pipeline stages:

1. **Checkout** - Pulls the `main` branch from GitHub.
2. **Terraform Plan and Create ECR** - Initializes Terraform and provisions the ECR repository.
3. **Build Docker Image** - Builds the image and tags it with the Jenkins build ID.
4. **Push to ECR** - Authenticates with ECR and pushes the image.
5. **Terraform Apply Full Infrastructure** - Deploys the remaining infrastructure (VPC, ECS, ALB, etc.).
6. **Get Load Balancer DNS** - Prints the application URL.

### Jenkins Credentials Required

| Credential ID   | Type                 | Purpose                          |
|-----------------|----------------------|----------------------------------|
| `aws-creds`     | AWS Keys             | AWS access for Terraform/ECR    |
| `docker_user`   | Username/Password    | Docker Hub (for build auth)     |

## Deployment URL

After a successful pipeline run, the game is accessible at:

```
http://<load_balancer_dns>/game.html
```

The exact URL is printed by the pipeline and can also be retrieved from the Terraform output:

```bash
cd terraform
terraform output service_url
```

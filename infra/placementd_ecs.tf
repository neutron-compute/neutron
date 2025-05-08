module "placementd_ecs" {
  source       = "terraform-aws-modules/ecs/aws"
  version      = "5.10.0"
  cluster_name = var.placementd_ecs_cluster_name
  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.placementd_ecs_cluster_name}"
      }
    }
  }
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = var.fargate_capacity_provider_weight
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = var.fargate_spot_capacity_provider_weight
      }
    }
  }

  services = {
    placementd = {
      cpu    = 1024 #TODO: have a tf variable for this
      memory = 4096 #TODO: have a tf variable for this

      # Container definition(s)
      container_definitions = {
        placementd = {
          cpu       = 512  #TODO: have a tf variable for this
          memory    = 1024 #TODO: have a tf variable for this
          essential = true
          image     = "public.ecr.aws/aws-containers/ecsdemo-frontend:776fd50"
          port_mappings = [
            {
              name          = "placementd"
              containerPort = 80
              protocol      = "tcp"
            }
          ]

          # Example image used requires access to write to root filesystem
          readonly_root_filesystem = false

          log_configuration = {
            logDriver = "awslogs"
            options = {
              awslogs-group         = "/aws/ecs/${var.placementd_ecs_cluster_name}/placementd-service"
              awslogs-region        = var.region
              awslogs-stream-prefix = "/ecs"
            }
          }
          memory_reservation = 100
        }
      }

      load_balancer = {
        service = {
          target_group_arn = module.placementd_alb.target_groups["placementd"].arn
          container_name   = "placementd"
          container_port   = 80
        }
      }

      subnet_ids = var.subnet_ids
      security_group_rules = {
        alb_ingress_3000 = {
          type        = "ingress"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          description = "Service port"
          cidr_blocks = var.placementd_ingress_cidr_blocks
        }
        egress_all = {
          type        = "egress"
          from_port   = 0
          to_port     = 0
          protocol    = "-1"
          cidr_blocks = ["0.0.0.0/0"] #TODO: have a tf variable for this
        }
      }
    }
  }

  tags = var.tags
}

module "placementd_alb" {
  source                     = "terraform-aws-modules/alb/aws"
  version                    = "9.8.0"
  name                       = var.placementd_ecs_cluster_name
  load_balancer_type         = "application"
  vpc_id                     = var.vpc_id
  subnets                    = var.subnet_ids
  enable_deletion_protection = false

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0" #TODO: have a tf variable for this
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0" #TODO: have a tf variable for this
    }
  }

  listeners = {
    ex_http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "placementd"
      }
    }
  }

  target_groups = {
    placementd = {
      backend_protocol                  = "HTTP"
      backend_port                      = 80
      target_type                       = "ip"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      health_check = {
        enabled             = true
        healthy_threshold   = 5
        interval            = 30
        matcher             = "200"
        path                = "/"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        unhealthy_threshold = 2
      }

      # Theres nothing to attach here in this definition. Instead,
      # ECS will attach the IPs of the tasks to this target group
      create_attachment = false
    }
  }

  tags = var.tags
}


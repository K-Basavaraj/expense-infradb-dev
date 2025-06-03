module "backend" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.devops.id
  name                   = local.resource_name
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.backend_sg_id]
  subnet_id              = local.private_subnet_ids

  tags = merge(
    var.common_tags,
    var.backend_tags,
    {
      Name = local.resource_name
    }
  )
}

resource "null_resource" "backend" {
  # if the above instance id is Changes then its going to create new at that time this null resorrce trigger to  re-provisioning
  triggers = {
    instance_id = module.backend.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host     = module.backend.private_ip
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  #what ever the script is present in local it will send it to terraform 
  provisioner "file" {
    source      = "${var.backend_tags.Component}.sh" #backend.sh
    destination = "/tmp/backend.sh"                  #it will copy it to this loaction in the server 
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/backend.sh",                                                #execute access
      "sudo sh /tmp/backend.sh ${var.backend_tags.Component} ${var.environment}" #run the script arguments
    ]
  }

}
#Note: while create instance only provisinor will run after any updated provisnior will not run, so 
#to run this provisionor we again we can use terraform taint command 


#now we need to stop the server to take the image 
resource "aws_ec2_instance_state" "stopbackend" {
  instance_id = module.backend.id
  state       = "stopped"
  depends_on = [
    null_resource.backend
  ]
}

#after stoping the instance you have to take the AMI using 
resource "aws_ami_from_instance" "amibackend" {
  name               = local.resource_name
  source_instance_id = module.backend.id
  depends_on         = [aws_ec2_instance_state.stopbackend]
}

#Now delete the instance after taking AMI, using null resource if the resource for delete option is not there 
resource "null_resource" "backend_delete" {
  # if the above instance id is Changes then its going to create new at that time this null resorrce trigger to  re-provisioning
  triggers = {
    instance_id = module.backend.id
  }
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.backend.id}" #this command will delete the instance
  }
  depends_on = [aws_ami_from_instance.amibackend] 
}

resource "aws_lb_target_group" "backendlbtg" {
  name     = local.resource_name
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  health_check {
    healthy_threshold   = 2 #if contineously two request sucess means its healthy
    unhealthy_threshold = 2 #if contineously two request fail means its unhealthy
    interval            = 5 #every 5 seconds the request will go
    matcher             = "200-299"
    path                = "/health"
    port                = 8080
    protocol            = "HTTP"
    timeout             = 4 #if the response is not comming even after 4 sec then its unhealthy
  }
}

#launch template is input for for autoscalling group
resource "aws_launch_template" "backendtemp" {
  name                                 = local.resource_name
  image_id                             = aws_ami_from_instance.amibackend.id
  instance_initiated_shutdown_behavior = "terminate" #whenever the traffic is decrese it will automatically delete so used terminate
  instance_type                        = "t3.micro"
  vpc_security_group_ids               = [local.backend_sg_id]
  update_default_version               = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = local.resource_name
    }
  }
}

resource "aws_autoscaling_group" "backendasg" {
  name                      = local.resource_name
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2 #start of the autoscaleing group
  # force_delete              = true
  target_group_arns = [aws_lb_target_group.backendlbtg.arn]
  launch_template {
    id      = aws_launch_template.backendtemp.id
    version = "$Latest"
  }
  vpc_zone_identifier = [local.private_subnet_ids]

  # Enables rolling replacement of instances when launch template changes (e.g., new AMI, patches, config updates),
  # updating them gradually while keeping at least 50% healthy to prevent downtime.
  # This handles instance version updates, not scaling based on CPU or load.
  instance_refresh {
    strategy = "Rolling"
    # Ensures at least 50% of instances (e.g., 2 out of 4) stay healthy and running during updates,
    # preventing downtime by not replacing too many instances at once.
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"] # tells the instance refresh process to start
  }
  tag {
    key                 = "Name"
    value               = local.resource_name
    propagate_at_launch = true
  }
  #if instances or not healthy within 15min, autoscaling  will delete that instance
  timeouts {
    delete = "15m"
  }

  tag {
    key                 = "project"
    value               = "expense"
    propagate_at_launch = false
  }
}

# ASG doesn’t know when to scale on its own; this policy tells it to scale
# instances up or down based on CPU usage targeting 70% utilization.
resource "aws_autoscaling_policy" "backendapol" {
  # ... other configuration ...
  name                   = local.resource_name
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.backendasg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_lb_listener_rule" "backendalb_rule" {
  listener_arn = local.app_alb_listener_arn
  priority     = 100 #low priority evaluated first 

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backendlbtg.arn
  }
  condition {
    host_header {
      values = ["${var.backend_tags.Component}.app-${var.environment}.${var.zone_name}"] #backend.app-dev.basavadevops81s.online will forward to backend targetgroup
    }
  }
}

module "frontend" {
  source                 = "terraform-aws-modules/ec2-instance/aws"
  ami                    = data.aws_ami.devops.id
  name                   = local.resource_name
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.frontend_sg_id]
  subnet_id              = local.public_subnet_ids

  tags = merge(
    var.common_tags,
    var.frontend_tags,
    {
      Name = local.resource_name
    }
  )
}

resource "null_resource" "frontend" {
  # Changes to any instance of the cluster requires re-provisioning
  triggers = {
    instance_id = module.frontend.id
  }

  # Bootstrap script can run on any instance of the cluster
  # So we just choose the first in this case
  connection {
    host     = module.frontend.private_ip
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
  }

  #what ever the script is present in local it will send it to terraform 
  provisioner "file" {
    source      = "${var.frontend_tags.Component}.sh" #frontend.sh
    destination = "/tmp/frontend.sh"                  #it will copy it to this loaction in the server 
  }

  provisioner "remote-exec" {
    # Bootstrap script called with private_ip of each node in the cluster
    inline = [
      "chmod +x /tmp/frontend.sh",                                                #execute access
      "sudo sh /tmp/frontend.sh ${var.frontend_tags.Component} ${var.environment}" #run the script arguments
    ]
  }

}
#Note: while create instance only provisinor will run after any updated provisnior will not run, so 
#to run this provisionor we again we can use terraform taint command 


#now we need to stop the server to take the image 
resource "aws_ec2_instance_state" "stopfrontend" {
  instance_id = module.frontend.id
  state       = "stopped"
  depends_on = [
    null_resource.frontend
  ]
}

#after stoping the instance you have to take the AMI using 
resource "aws_ami_from_instance" "amifrontend" {
  name               = local.resource_name
  source_instance_id = module.frontend.id
  depends_on         = [aws_ec2_instance_state.stopfrontend]
}

#Now elete the instance after taking AMI, using null resource if the resource for deleting is not there 
resource "null_resource" "deletefrontend" {
  triggers = {
    instance_id = module.frontend.id
  }

  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${module.frontend.id}"
  }
  depends_on = [aws_ami_from_instance.amifrontend]
}

resource "aws_lb_target_group" "frontendlbtg" {
  name     = local.resource_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  health_check {
    healthy_threshold   = 2 #if contineously two request sucess means its healthy
    unhealthy_threshold = 2 #if contineously two request fail means its unhealthy
    interval            = 5
    matcher             = "200-299"
    path                = "/"
    port                = 80
    protocol            = "HTTP"
    timeout             = 4
  }
}

resource "aws_launch_template" "frontendtemp" {
  name                                 = local.resource_name
  image_id                             = aws_ami_from_instance.amifrontend.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = "t3.micro"
  vpc_security_group_ids               = [local.frontend_sg_id]
  update_default_version               = true
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = local.resource_name
    }
  }
}

resource "aws_autoscaling_group" "frontendasg" {
  name                      = local.resource_name
  max_size                  = 10
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 2 #start of the autoscaleing group
  # force_delete              = true
  target_group_arns = [aws_lb_target_group.frontendlbtg.arn]
  launch_template {
    id      = aws_launch_template.frontendtemp.id
    version = "$Latest"
  }
  vpc_zone_identifier = [local.public_subnet_ids]
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
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

resource "aws_autoscaling_policy" "frontendapol" {
  # ... other configuration ...
  name                   = local.resource_name
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.frontendasg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 70.0
  }
}

resource "aws_lb_listener_rule" "frontendalbrule" {
  listener_arn = local.web_alb_listener_arn
  priority     = 100 #low priority evaluated first 

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontendlbtg.arn
  }
  condition {
    host_header {
      values = ["expense-${var.environment}.${var.zone_name}"] #expense-dev.basavadevops81s.online
    }
  }
}


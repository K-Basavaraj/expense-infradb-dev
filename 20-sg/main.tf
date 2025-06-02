############################### SECURITYGROUPS  ####################################
module "mysql_sg" {
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "mysql"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.mysql_sg_tags
}

module "backend_sg" {
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "backend"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.backend_sg_tags
}

module "frontend_sg" {
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "frontend"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.frontend_sg_tags
}

module "bastion_sg" {
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "bastion"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.bastion_sg_tags
}

module "ansible_sg" {
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "ansible"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.ansible_sg_tags
}

module "app_alb_sg" { #applocation loadbalancer secuirty group
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "app-alb"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.app_alb_sg_tags
}

module "web_alb_sg" { #aweb pplocation loadbalancer secuirty group
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "web-alb"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
  sg_tags      = var.web_alb_sg_tags
}

module "vpn_sg" { #applocation loadbalancer secuirty group
  source       = "git::https://github.com/K-Basavaraj/terraform-aws-secuirty-group.git?ref=main"
  project_name = var.project_name
  environment  = var.environment
  sg_name      = "vpn"
  vpc_id       = local.vpc_id
  common_tags  = var.common_tags
}

###############################SECUIRTYGROUPRULES###############################################
# Security Group Rules Structure Order:
# * Frontend Load Balancer SG Rules
# * Frontend Server SG Rules
# * Backend Load Balancer SG Rules
# * Backend Server SG Rules
# * MySQL (RDS) SG Rules
# * VPN SG Rules
# * Bastion and Ansible SG Rules
##############################################################################################
####################################### FRONTEND ALB(WEBALB)####################################
# When a user makes a request to your domain (e.g., www.example.com), the DNS resolves the
#domain to the ALB's endpoint.
# The request then reaches this public-facing Application Load Balancer (ALB).
# This ALB is configured to accept HTTP (port 80) and HTTPS (port 443) traffic from any source.

#webalb(frontendALB) is accepting the connection from public 80
resource "aws_security_group_rule" "web_alb_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.web_alb_sg.id #where your creating this rule
}

#webalb(frontendALB) is accepting the connection from public 443
resource "aws_security_group_rule" "web_alb_http443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.web_alb_sg.id #where your creating this rule
}
###############################################################################################

################################## FRONTEND SERVERS ###########################################

# The frontend servers accept traffic from different trusted sources depending on the port:
# - From the frontend ALB (webalb) on port 80 for HTTP traffic
# - From the Bastion host, VPN, or Ansible on port 22 for SSH access (administration or automation)

#frontendservers accepting connection from webalb(frontendALB)on port 80
resource "aws_security_group_rule" "frontend_web_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.web_alb_sg.id
  security_group_id        = module.frontend_sg.id #where your creating this rule
}

#frontend accepting the connection from vpn can also use insted of bastion on port 22
resource "aws_security_group_rule" "frontend_vpn" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.vpn_sg.id
  security_group_id        = module.frontend_sg.id #where your creating this rule
}

#frontendserver accepting connection from bastion on port 22
resource "aws_security_group_rule" "frontend_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.bastion_sg.id  #accept connection from this source
  security_group_id        = module.frontend_sg.id #where your creating this rule
}

#frontendserver accepting connection from ansible on port 22
resource "aws_security_group_rule" "frontend_ansible" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.ansible_sg.id  #accept connection from this source
  security_group_id        = module.frontend_sg.id #where your creating this rule
}

# Note:
# Instead of logging into a Bastion host or managing access via an Ansible server,
# VPN access can be used for simpler and more secure connectivity.
# With VPN enabled, users can directly SSH into the frontend servers from their local machines
# without needing to hop through a Bastion, making debugging or admin tasks easier.
################################################################################################

####################################### BACKENDALB ##############################################
# The backend Application Load Balancer (app-alb) accepts incoming traffic on port 80
# from trusted sources including:
# - Frontend servers (which forward client requests)
# - Bastion host (for administrative or troubleshooting access)
# - VPN (as an alternative to Bastion for easier and secure access)
# - (Optionally) Ansible server for automation and configuration management

#app-alb(backendalb) accepting connection from frontendserver on port 80
resource "aws_security_group_rule" "app_alb_frontend" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.frontend_sg.id
  security_group_id        = module.app_alb_sg.id #where your creating this rule
}

#app-alb(backendalb) accepting connection from bastion on port 80
resource "aws_security_group_rule" "app_alb_bastion" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.bastion_sg.id #accept connection from this source
  security_group_id        = module.app_alb_sg.id #where your creating this rule
}

#app-alb(backendalb) accepting connection from vpn can also use insted of bastion
resource "aws_security_group_rule" "app_alb_vpn" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.vpn_sg.id
  security_group_id        = module.app_alb_sg.id #where your creating this rule
}
###########################################################################################

#################################### BACKENDservers ########################################
# Backend servers accept incoming connections on different ports from trusted sources:
# - From the backend Application Load Balancer (app-alb) on port 8080 for application traffic
# - From Bastion host, VPN, and Ansible server on port 22 for SSH access (administration and automation)
# Allow VPN clients to access backend applications on port 8080
# (commonly used for backend app traffic, useful for internal access via VPN)

# Two rules allow app traffic on port 8080 (from ALB and VPN).
# Two rules allow SSH access on port 22 (from Bastion and VPN).

#backendserver accepting connection from appalb(orbackend loadbalancer) on port 8080
resource "aws_security_group_rule" "backend_app_alb" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = module.app_alb_sg.id #accept connection from this source
  security_group_id        = module.backend_sg.id #where your creating this rule
}

#backendservers accepting connection from bastion on port 22
resource "aws_security_group_rule" "backend_bastion" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.bastion_sg.id #accept connection from this source
  security_group_id        = module.backend_sg.id #where your creating this rule
}

#backendserver accepting connection from vpn can also use insted of bastion on port 22
resource "aws_security_group_rule" "backend_vpn" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.vpn_sg.id
  security_group_id        = module.backend_sg.id #where your creating this rule
}

#backend accepting connection from vpn
resource "aws_security_group_rule" "backend_vpn_8080" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = module.vpn_sg.id
  security_group_id        = module.backend_sg.id #where your creating this rule
}

#backendserver accepting connection from ansibles on port 22
resource "aws_security_group_rule" "backend_ansible" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = module.ansible_sg.id #accept connection from this source
  security_group_id        = module.backend_sg.id #where your creating this rule
}
#############################################################################################

######################################## MYSQL (RDS) #########################################
# The MySQL RDS instance accepts incoming connections on port 3306
# from trusted sources such as:
# - Backend servers (application servers) for normal database traffic
# - Bastion host for administrative or troubleshooting access

#mysql(RDS) accepting connection from backend on port 3306
resource "aws_security_group_rule" "mysql_backend" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.backend_sg.id #accept connection from this source
  security_group_id        = module.mysql_sg.id   #where your creating this rule
}

#mysql(RDS) accepting connection from bastion on port 3306
resource "aws_security_group_rule" "mysql_bastion" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = module.bastion_sg.id #accept connection from this source
  security_group_id        = module.mysql_sg.id   #where your creating this rule
}
###########################################################################################

######################################## VPN ############################################
# For secure management of the VPN server, SSH access on port 22 is allowed.
# Other ports are required for OpenVPN functionality and client connectivity:
# - 443: HTTPS for secure web access or VPN client portals (used for SSL VPN or web UIs)
# - 943: OpenVPN web interface port, common for the OpenVPN Access Server management UI
# - 1194: Default OpenVPN port (UDP or TCP) for establishing VPN tunnels
#
# These ports ensure that OpenVPN clients can connect and communicate properly.
# Even if the exact usage of some ports (like 943) may vary depending on your setup,
# they are commonly required for OpenVPN to work smoothly.

#vpn accepting connection from internet
resource "aws_security_group_rule" "vpn_public" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpn_sg.id #where your creating this rule
}

resource "aws_security_group_rule" "vpn_public_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpn_sg.id #where your creating this rule
}

resource "aws_security_group_rule" "vpn_public_943" {
  type              = "ingress"
  from_port         = 943
  to_port           = 943
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpn_sg.id #where your creating this rule
}

resource "aws_security_group_rule" "vpn_public_1194" {
  type              = "ingress"
  from_port         = 1194
  to_port           = 1194
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.vpn_sg.id #where your creating this rule
}
############################################################################

############################# BASTION/ANSIBLE SERVER—Accepting SSH from Internet#############################

# This rule allows SSH (port 22) access to the Bastion host from any IP address on the internet.
# WARNING: Using 0.0.0.0/0 means the whole world can attempt to connect — this is NOT secure for production.
# RECOMMENDED: Replace with your office/home IPs like ["203.0.113.10/32"] for better security.

# Purpose:
# - These Bastion and Ansible hosts are used to connect to internal backend servers (which are in private subnets).
# - They also help debug and SSH into backend EC2 instances and inspect internal ALB (Application Load Balancer) connectivity issues.
# - Bastion is the jump host; Ansible is used for configuration management and remote commands.
# NOTE: These rules only allow inbound SSH — internet **access from** the instance depends on subnet, public IP, and routing.

#bastion accepting connection from internet
resource "aws_security_group_rule" "bastion_public" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  #Allow from ANY IP (not secure for production!) here we need to give officeips
  security_group_id = module.bastion_sg.id #where your creating this rule
}

#ansible accepting connection from internet
resource "aws_security_group_rule" "ansible_public" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"] #Allow from ANY IP (not secure for production!) here we need to give officeips
  security_group_id = module.ansible_sg.id #where your creating this rule
}

#######################################################################################################

# # backend accepting connection from frontend
# resource "aws_security_group_rule" "backend_frontend" {
#   type                     = "ingress"
#   from_port                = 8080
#   to_port                  = 8080
#   protocol                 = "tcp"
#   source_security_group_id = module.frontend_sg.id #accept connection from this source
#   security_group_id        = module.backend_sg.id  #where your creating this rule
# }

# # frontend accepting connection from public(internet)
# resource "aws_security_group_rule" "frontend_public" {
#   type              = "ingress"
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]         #accept connection from this source
#   security_group_id = module.frontend_sg.id #where your creating this rule
# }

# #mysql accepting connection from ansible
# resource "aws_security_group_rule" "mysql_ansible" {
#   type                     = "ingress"
#   from_port                = 22
#   to_port                  = 22
#   protocol                 = "tcp"
#   source_security_group_id = module.ansible_sg.id #accept connection from this source
#   security_group_id        = module.mysql_sg.id   #where your creating this rule
# }


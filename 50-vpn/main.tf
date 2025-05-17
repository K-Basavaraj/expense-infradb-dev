resource "aws_key_pair" "openvpn" {
  key_name   = "openvpn"
  public_key = local.sensitive_public_key
}

#This module vpn has some issue while configuring the vpn where unable to connect vpn afersetup so using resource
# module "vpn" {
#   source                 = "terraform-aws-modules/ec2-instance/aws"
#   ami                    = data.aws_ami.devops.id
#   name                   = local.resource_name
#   key_name               = aws_key_pair.openvpn.key_name
#   instance_type          = "t3.micro"
#   vpc_security_group_ids = [local.vpn_sg_id]
#   subnet_id              = local.public_subnet_ids
#   #user_data              = file("user-data.sh")
#   tags = merge(
#     var.common_tags,
#     var.vpn_tags,
#     {
#       Name = local.resource_name
#     }
#   )
# }

resource "aws_instance" "vpn" {
  ami                    = data.aws_ami.openvpn.id
  key_name               = aws_key_pair.openvpn.key_name
  instance_type          = "t3.micro"
  vpc_security_group_ids = [local.vpn_sg_id]
  subnet_id              = local.public_subnet_ids
  #Giving the userdata path
  #user_data = file("user-data.sh")
  tags = merge(
    var.common_tags,
    var.vpn_tags,
    {
      Name = local.resource_name
    }
  )
}

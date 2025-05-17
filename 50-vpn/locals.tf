locals {
  resource_name     = "${var.project_name}-${var.environment}-vpn"
  sensitive_public_key = sensitive(file("~/.ssh/openvpn.pub"))
  vpn_sg_id         = data.aws_ssm_parameter.vpn_sg_id.value
  public_subnet_ids = split(",", data.aws_ssm_parameter.public_subnet_ids.value)[0] #convert stringlist to list and select particular subnet
}

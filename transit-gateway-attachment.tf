data "aws_ec2_transit_gateway_route_table" "type" {
  provider = aws.transit-gateway-host

  filter {
    name   = "tag:Name"
    values = [var.type]
  }

  filter {
    name   = "transit-gateway-id"
    values = [var.transit_gateway_id]
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "main" {
  subnet_ids = [ for key, subnet in aws_subnet.subnets : subnet.id if substr(key, 0, 15) == "transit-gateway" ]
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.vpc.id
  appliance_mode_support                          = "disable"
  dns_support                                     = "enable"
  ipv6_support                                    = "disable"
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(
    var.tags_common,
    { Name = format("%s-attachment", var.tags_prefix) },
  )

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ec2_tag" "retag" {
  for_each = merge(
    var.tags_common,
    { Name = format("%s-attachment", var.tags_prefix) }
  )
  provider = aws.transit-gateway-host

  resource_id = aws_ec2_transit_gateway_vpc_attachment.main.id

  key   = each.key
  value = each.value
}

## Associate the Transit Gateway Route Table with the VPC
resource "aws_ec2_transit_gateway_route_table_association" "type" {
  provider = aws.transit-gateway-host

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.main.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.type.id
}

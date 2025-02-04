data "aws_ec2_transit_gateway" "transit-gateway" {
  provider = aws.core-network-services
  filter {
    name   = "options.amazon-side-asn"
    values = ["64589"]
  }
}

## Look up RAM Resource Share in the host account
data "aws_ram_resource_share" "transit-gateway" {
  provider = aws.core-network-services

  name           = "transit-gateway"
  resource_owner = "SELF"
}

## Get the Transit Gateway tenant account ID
data "aws_caller_identity" "transit-gateway-tenant" {
}

## Add the tenant account to the Transit Gateway Resource Share
## REMOVAL OF THIS RESOURCE WILL STOP ALL VPC ACCOUNT TRAFFIC VIA THE TRANSIT GATEWAY
resource "aws_ram_principal_association" "transit_gateway_association" {
  provider = aws.core-network-services

  principal          = data.aws_caller_identity.transit-gateway-tenant.account_id
  resource_share_arn = data.aws_ram_resource_share.transit-gateway.arn
}


# Data lookups


## Look up Transit Gateway Route Tables in the host account to associate with
data "aws_ec2_transit_gateway_route_table" "default" {
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

# Resource creation

## Due to propagation in AWS, a RAM share will take up to 60 seconds to appear in an account,
## so we need to wait before attaching our tenant VPCs to it
resource "time_sleep" "wait_60_seconds" {
  create_duration = "60s"
}

## Attach provided subnet IDs and VPC to the provided Transit Gateway ID
resource "aws_ec2_transit_gateway_vpc_attachment" "default" {
  provider = aws.transit-gateway-tenant

  subnet_ids         = var.subnet_ids
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = var.vpc_id

  appliance_mode_support = "disable"
  dns_support            = "enable"
  ipv6_support           = "disable"

  # You can't change these with a RAM-shared Transit Gateway, but we'll
  # leave them here to be explicit.
  transit_gateway_default_route_table_association = true
  transit_gateway_default_route_table_propagation = true

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-attachment"
  })

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [
    time_sleep.wait_60_seconds
  ]
}

## Associate the Transit Gateway Route Table with the VPC
resource "aws_ec2_transit_gateway_route_table_association" "default" {
  provider = aws.transit-gateway-host

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.default.id
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default.id
}

## Retag the new Transit Gateway VPC attachment in the Transit Gateway host
resource "aws_ec2_tag" "retag" {
  for_each = var.tags
  provider = aws.transit-gateway-host

  resource_id = aws_ec2_transit_gateway_vpc_attachment.default.id

  key   = each.key
  value = each.value
}

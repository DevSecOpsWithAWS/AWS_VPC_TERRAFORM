resource "aws_vpc" "expense_vpc" {
  cidr_block       = var.cidr_block #"10.0.0.0/16"
  instance_tenancy = var.instance_tenancy
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
    var.common_tags,
    var.vpc_tags,
    {
        Name = "${local.resource_name}-vpc"
    }
  )
}

resource "aws_internet_gateway" "expense_igw" {
  vpc_id = aws_vpc.expense_vpc.id

  tags = merge(
    var.common_tags,
    var.igw_tags,
    {
        Name = "${local.resource_name}-igw"
    }
  )
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr)
  vpc_id     = aws_vpc.expense_vpc.id
  cidr_block = var.public_subnet_cidr[count.index]
  availability_zone = local.azs_names[count.index]
  map_public_ip_on_launch = true
  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-public-${local.azs_names[count.index]}"
    }
  )
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr)
  vpc_id     = aws_vpc.expense_vpc.id
  cidr_block = var.private_subnet_cidr[count.index]
  availability_zone = local.azs_names[count.index]
  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-private-${local.azs_names[count.index]}"
    }
  )
}
resource "aws_subnet" "database" {
  count = length(var.database_subnet_cidr)
  vpc_id     = aws_vpc.expense_vpc.id
  cidr_block = var.database_subnet_cidr[count.index]
  availability_zone = local.azs_names[count.index]
  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-database-${local.azs_names[count.index]}"
    }
  )
}

resource "aws_eip" "nat" {
  domain   = "vpc"
}

resource "aws_nat_gateway" "example" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}"
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.expense_igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.expense_vpc.id

  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-public"
    }
  )
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.expense_vpc.id

  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-private"
    }
  )
}
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.expense_vpc.id

  tags = merge(
    var.common_tags,
    {
        Name = "${local.resource_name}-database"
    }
  )
}

resource "aws_route" "public" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.expense_igw.id
}

resource "aws_route" "private" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  #gateway_id = aws_internet_gateway.expense_igw.id
  nat_gateway_id = aws_nat_gateway.example.id
}
resource "aws_route" "database" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  #gateway_id = aws_internet_gateway.expense_igw.id
  nat_gateway_id = aws_nat_gateway.example.id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidr)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidr)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidr)
  subnet_id      = aws_subnet.database[count.index].id
  route_table_id = aws_route_table.database.id
}
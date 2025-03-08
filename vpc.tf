resource "aws_vpc" "packer" {
  cidr_block = "172.30.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.packer.id
  cidr_block        = "172.30.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "packer-subnet"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.packer.id
  cidr_block        = "172.30.2.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "public-subnet"
  }
}

resource "aws_eip" "nat_gateway" {
}

resource "aws_nat_gateway" "public" {
  connectivity_type = "public"
  subnet_id         = aws_subnet.public.id
  allocation_id     = aws_eip.nat_gateway.id
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.packer.id
}

# see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table#adopting-an-existing-local-route on how to adopt the default route table
# resource "aws_route_table" "private" {
#   vpc_id = aws_vpc.packer.id
#   route {
#    cidr_block = aws_vpc.packer.cidr_block
#    gateway_id = "local"
#  }
# }

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.packer.id
  route {
   cidr_block = aws_vpc.packer.cidr_block
   gateway_id = "local"
  }
  route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_nat_gateway.public.id
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.packer.id
  route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.igw.id
 }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
resource "aws_vpc" "packer" {
  cidr_block = "172.30.0.0/16"
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.packer.id
  cidr_block        = "172.30.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.packer.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.packer.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
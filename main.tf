resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "mysubnet1" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "mysubnet2" {
  vpc_id                  = aws_vpc.myvpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.myvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}


resource "aws_route_table_association" "rta1" {
  subnet_id      = aws_subnet.mysubnet1.id
  route_table_id = aws_route_table.rt.id
}


resource "aws_route_table_association" "rta2" {
  subnet_id      = aws_subnet.mysubnet2.id
  route_table_id = aws_route_table.rt.id
}


resource "aws_security_group" "sg" {
  name   = "my-sg"
  vpc_id = aws_vpc.myvpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH for VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    description = "All allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg"
  }
}


resource "aws_s3_bucket" "name" {
  bucket = "newvvnbucket2024"
}


resource "aws_instance" "webserver" {
  ami                    = "ami-00beae93a2d981137"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.mysubnet1.id
  user_data              = base64encode(file("webserver_userdata.sh"))

  tags = {
    Name = "webserver"
  }

}


resource "aws_instance" "dbserver" {
  ami                    = "ami-04b70fa74e45c3917"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.mysubnet2.id
  user_data              = base64encode(file("dbserver_userdata.sh"))
  tags = {
    Name = "dbserver"
  }
}

resource "aws_lb" "alb" { //create the Load Balancer
  name               = "my-lb-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.sg.id]
  subnets            = [aws_subnet.mysubnet1.id, aws_subnet.mysubnet2.id]
}

resource "aws_lb_target_group" "target" { //Create the Target Group
  name     = "my-lb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}


resource "aws_lb_target_group_attachment" "attach1" { //Attach the Target Group withg EC2 Instance
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.webserver.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.target.arn
  target_id        = aws_instance.dbserver.id
  port             = 80
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.target.arn
    type             = "forward"
  }

}

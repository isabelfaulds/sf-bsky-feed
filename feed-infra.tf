provider "aws" {
  region = "us-west-1"
}

variable "bsky_tags" {
  description = "Tags for all sf bsky feed resources"
  type        = map(string)
  default     = {
    Project = "sf-bsky-feed"
    Environment = "production"
  }
}

### Permissions
 

# Secrets Manager Access
resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "ssm_policy" {
  name        = "SSMReadOnlyPolicy"
  description = "Allow EC2 instances to read SSM parameters"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.ssm_policy.arn
}

resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "ec2_ssm_profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# Cloudwatch monitoring


resource "aws_iam_role" "cloudwatch_agent_role" {
  name = "CloudWatchAgentRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cloudwatch_agent_policy" {
  name = "CloudWatchAgentPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "cloudwatch:PutMetricData"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attach" {
  role       = aws_iam_role.cloudwatch_agent_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent_policy.arn
}


### Infra resources

resource "aws_vpc" "feed_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = merge(var.bsky_tags, {
    Name = "feed_vpc"
  })
}

resource "aws_subnet" "feed_subnet" {
  vpc_id            = aws_vpc.feed_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-west-1a" # Adjust as needed

  tags = merge(var.bsky_tags, {
    Name = "feed_subnet"
  })
}

resource "aws_internet_gateway" "feed_igw" {
  vpc_id = aws_vpc.feed_vpc.id

  tags = merge(var.bsky_tags, {
    Name = "feed_igw"
  })
}

resource "aws_route_table" "feed_route_table" {
  vpc_id = aws_vpc.feed_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.feed_igw.id
  }

  tags = merge(var.bsky_tags, {
    Name = "feed_route_table"
  })
}

resource "aws_route_table_association" "feed_route_table_association" {
  subnet_id      = aws_subnet.feed_subnet.id
  route_table_id = aws_route_table.feed_route_table.id
}

resource "aws_security_group" "feed_server_sg" {
  vpc_id = aws_vpc.feed_vpc.id

# home network ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["24.4.37.147/32", "98.207.205.66/32", "192.168.1.100/32"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# ec2 reachable for bluesky
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

# ec2 access to internet ie pip install
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.bsky_tags, {
    Name = "feed_server_sg"
  })
}

resource "aws_instance" "feed_server" {
  ami                  = "ami-066f98455b59ca1ee" # Amazon Linux 2 AMI
  instance_type        = "t3.medium"
  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name
  subnet_id            = aws_subnet.feed_subnet.id
  key_name             = "sf-bsky-feed-key"
  vpc_security_group_ids = [aws_security_group.feed_server_sg.id]
  
  tags = merge(var.bsky_tags, {
    Name = "feed_instance"
  })

  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo amazon-linux-extras install -y python3.8
              sudo yum install -y httpd git

              git clone https://github.com/manyshapes/sf-bsky-feed /home/ec2-user/sf-bsky-feed
              cd /home/ec2-user/sf-bsky-feed

              sudo python3.8 -m venv venv
              source venv/bin/activate
              sudo /home/ec2-user/sf-bsky-feed/venv/bin/python3 -m pip install --upgrade pip
              sudo chown -R ec2-user:ec2-user /home/ec2-user/sf-bsky-feed
              chmod 775 /home/ec2-user/sf-bsky-feed
              
              pip install -r requirements.txt

              flask run
              EOF
}

resource "aws_eip" "feed_server_eip" {
  instance = aws_instance.feed_server.id
  domain   = "vpc"
}

output "feed_server_eip" {
  value = aws_eip.feed_server_eip.public_ip
}

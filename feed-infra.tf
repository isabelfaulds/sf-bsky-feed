provider "aws" {
  region = "us-west-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
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
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole",
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
          "ec2:DescribeAddresses",
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
  availability_zone = "us-west-1a"

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

  # flask port
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
              sudo yum install -y httpd git aws-cli

              git clone https://github.com/manyshapes/sf-bsky-feed /home/ec2-user/sf-bsky-feed
              # May be out of date, referncing aws
              eip=$(aws ec2 describe-addresses --filters "Name=instance-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" --query "Addresses[0].PublicIp" --output text --region us-west-1)
              if grep -q "HOSTNAME=" /home/ec2-user/sf-bsky-feed/.env; then
                sed -i "s/HOSTNAME=.*/HOSTNAME=$eip/" /home/ec2-user/sf-bsky-feed/.env
              else
                echo "HOSTNAME=$eip" >> /home/ec2-user/sf-bsky-feed/.env
              fi

              cd /home/ec2-user/sf-bsky-feed
              sudo python3.8 -m venv venv
              source venv/bin/activate
              sudo /home/ec2-user/sf-bsky-feed/venv/bin/python3 -m pip install --upgrade pip
              
              # Ensuring permissions for application file writing
              sudo chown -R ec2-user:ec2-user /home/ec2-user/sf-bsky-feed
              chmod -R 775 /home/ec2-user/sf-bsky-feed
              
              pip install -r requirements.txt
              export FLASK_APP=app.py
              export FLASK_ENV=development

              cd server

              flask run --host=0.0.0.0 --port=5000
              EOF
}

resource "aws_eip" "feed_server_eip" {
  instance = aws_instance.feed_server.id
  domain   = "vpc"
}

output "feed_server_eip" {
  value = aws_eip.feed_server_eip.public_ip
}

# using an already created domain
data "aws_route53_zone" "personal_domain" {
  name = "isabelfaulds.com"
}

# ACM Certificates for Cloudfront live in us-east-1
resource "aws_acm_certificate" "feed_cert" {
  provider = aws.us_east_1 

  domain_name = "isabelfaulds.com"
  validation_method = "DNS"

  # including www.
  subject_alternative_names = [
    "www.isabelfaulds.com"
  ]

  tags = {
    Name = "Personal Cert"
  }
}

# DNS Validation Record for ACM Certificate root domain
resource "aws_route53_record" "cert_validation" {
depends_on = [aws_acm_certificate.feed_cert]

  zone_id = data.aws_route53_zone.personal_domain.zone_id
  name    = tolist(aws_acm_certificate.feed_cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.feed_cert.domain_validation_options)[0].resource_record_type
  ttl     = "60"
  records = [tolist(aws_acm_certificate.feed_cert.domain_validation_options)[0].resource_record_value]
}

# DNS Validation Record for ACM Certificate www subdomain
resource "aws_route53_record" "cert_validation_www" {
  depends_on = [aws_acm_certificate.feed_cert]

  zone_id = data.aws_route53_zone.personal_domain.zone_id
  name    = tolist(aws_acm_certificate.feed_cert.domain_validation_options)[1].resource_record_name
  type    = tolist(aws_acm_certificate.feed_cert.domain_validation_options)[1].resource_record_type
  ttl     = "60"
  records = [tolist(aws_acm_certificate.feed_cert.domain_validation_options)[1].resource_record_value]
}

resource "aws_route53_record" "origin_record" {
  zone_id = data.aws_route53_zone.personal_domain.zone_id
  name    = "origin"
  type    = "A"
  ttl     = 300
  records = [aws_eip.feed_server_eip.public_ip]
}

resource "aws_cloudfront_distribution" "feed_distribution" {
  depends_on = [aws_acm_certificate.feed_cert]
  aliases = ["isabelfaulds.com", "www.isabelfaulds.com"]

  origin {
    domain_name = "origin.isabelfaulds.com"
    origin_id   = "EC2Origin"
      custom_origin_config {
      http_port = 5000
      https_port = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols    = ["TLSv1.2"]
      origin_read_timeout = 60
    }
  }

  enabled          = true
  is_ipv6_enabled  = true

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = "EC2Origin"

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
  }

  # Edges for Americas, Europe, Asia 
  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.feed_cert.arn
    ssl_support_method   = "sni-only"
  }

}



resource "aws_route53_record" "feed_domain" {
  zone_id = data.aws_route53_zone.personal_domain.zone_id
  name    = "isabelfaulds.com"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.feed_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.feed_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_feed_domain" {
  zone_id = data.aws_route53_zone.personal_domain.zone_id
  name    = "www.isabelfaulds.com"
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.feed_distribution.domain_name]
}

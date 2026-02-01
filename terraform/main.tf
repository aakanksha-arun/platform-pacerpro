#ec2
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "webapp_vm" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name = "HelloWorld"
  }
}
#sns topic
resource "aws_sns_topic" "log_alerts" {
  name = "log-alerts-topic"
}
#lambda
# IAM role for Lambda execution
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "example" {
  name               = "lambda_execution_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Package the Lambda function code
data "archive_file" "example" {
  type        = "zip"
  source_file = "${path.module}/../aws_lambda.py"
  output_path = "${path.module}/lambda/function.zip"
}

# Lambda function
resource "aws_lambda_function" "rebooter_publisher" {
  filename      = data.archive_file.example.output_path
  function_name = "rebooter_publisher"
  role          = aws_iam_role.example.arn
  handler       = "aws_lambda.lambda_handler"

  runtime = "python3.14"

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.webapp_vm.id
      SNS_TOPIC_ARN = aws_sns_topic.log_alerts.arn
    }
  }
}

#iam policy
data "aws_iam_policy_document" "reboot_publish_policy_doc" {
  statement {
    actions = [
      "ec2:RebootInstances",
    ]

    resources = [
      aws_instance.webapp_vm.arn
    ]
  }

  statement {
    actions = [
      "sns:Publish",
    ]

    resources = [
      aws_sns_topic.log_alerts.arn,
    ]

  }

}

resource "aws_iam_policy" "reboot_publish_policy" {
  name   = "reboot_publish_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.reboot_publish_policy_doc.json
}

#iam role
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.example.name
  policy_arn = aws_iam_policy.reboot_publish_policy.arn
}

#fn url
resource "aws_lambda_function_url" "public_function_url" {
  function_name      = aws_lambda_function.rebooter_publisher.function_name
  authorization_type = "NONE"
}
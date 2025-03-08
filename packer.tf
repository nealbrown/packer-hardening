# Generic assume role policy used by Packer and EC2
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_policy" "packer_policy" {
  name        = "cis-packer-build-policy"
  path        = "/"
  description = "Allow Packer to build AMIs."

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" : "Allow",
        "Action" : "iam:PassRole",
        "Resource" : [
          # IAM Json does not allow us to lookup the current account
          "arn:aws:iam::1234567890:role/*"
        ]
      },
      {
        "Action" : [
          "iam:GetInstanceProfile"
        ],
        "Resource" : [
          "arn:aws:iam::*:instance-profile/*"
        ],
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:DescribeLogGroups"
        ],
        "Resource" : [
          "arn:aws:logs:*:*:log-group:*"
        ],
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "ec2:DescribeInstances",
          "ec2:CreateKeyPair",
          "ec2:DescribeRegions",
          "ec2:DescribeVolumes",
          "ec2:DescribeSubnets",
          "ec2:DeleteKeyPair",
          "ec2:DescribeSecurityGroups"
        ],
        "Resource" : [
          "*"
        ],
        "Effect" : "Allow"
      }

    ]
  })
}
data "aws_iam_policy" "AmazonSSMManagedInstanceCore" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# Role from which to create the instance profile
resource "aws_iam_role" "packer_role" {
  name               = "cis-packer-build-policy"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
# Attach the S3 policy above to the new iam role
resource "aws_iam_role_policy_attachment" "packer_policy_attach" {
  role       = aws_iam_role.packer_role.name
  policy_arn = aws_iam_policy.packer_policy.arn
}
resource "aws_iam_role_policy_attachment" "packer_SSM_policy_attach" {
  role       = aws_iam_role.packer_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}
resource "aws_iam_instance_profile" "packer_instance_profile" {
  name = "cis-packer-build-policy-profile"
  role = aws_iam_role.packer_role.name
}

packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

data "amazon-ami" "amazon-linux-latest" {
    filters = {
        virtualization-type = "hvm"
        name = "al2023-ami-2023.6.2025*"
        root-device-type = "ebs"
        architecture = "arm64"
    }
    owners = ["amazon"]
    most_recent = true
}

source "amazon-ebs" "cis" {
  ami_name      = "packer-cis-linux-aws-{{timestamp}}"
  instance_type = "t4g.medium"
  region        = "us-east-1"
  source_ami    = data.amazon-ami.amazon-linux-latest.id
  ssh_username  = "ec2-user"
  # https://aws.amazon.com/blogs/mt/creating-packer-images-using-system-manager-automation/
  # https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs#iam-instance-profile-for-systems-manager
  ssh_interface = "session_manager"
  communicator  = "ssh" 
  iam_instance_profile = "cis-packer-build-policy-profile" # Adapted from TF SSM role for testing based on docs above

  vpc_filter {
    filters = {
      "isDefault": "true"
    }
  }
  subnet_filter {
    filters = {
    }
  }
  # enforces imdsv2 support on the running instance being provisioned by Packer
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
    http_put_response_hop_limit = 1
  }
  imds_support  = "v2.0" # enforces imdsv2 support on the resulting AMI
}

build {
  name = "Run Initial Config" 
  sources = [
    "source.amazon-ebs.cis"
  ]
  provisioner "shell" {
    inline = [
      "echo Connected via SSM at '${build.User}@${build.Host}:${build.Port}'",
      "sudo yum -y install amazon-cloudwatch-agent",
      # We accept the default dd agent version here
      # "sudo DD_API_KEY=PREINSTALL DD_INSTALL_ONLY=true DD_SITE=datadoghq.com bash -c \"$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)\""
    ]
  }
}

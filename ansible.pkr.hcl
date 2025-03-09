packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = "~> 1"
      source = "github.com/hashicorp/ansible"
    }
    password = {
      version = ">= 0.1.0"
      source  = "github.com/alexp-computematrix/password"
    }
  }
}

# Find latest 
# `aws ec2 describe-images --owners amazon --filters "Name=name,Values=al2023-ami-2023*" "Name=architecture,Values=arm64" --query 'sort_by(Images, &CreationDate)[].Name'`
data "amazon-ami" "amazon-linux-latest" {
  filters = {
    virtualization-type = "hvm"
    name                = "al2023-ami-2023.6.2025*"
    root-device-type    = "ebs"
    architecture        = "arm64"
  }
  owners      = ["amazon"]
  most_recent = true
}

data "password" "root" {}

source "amazon-ebs" "cis" {
  ami_name      = "packer-cis-linux-aws-{{timestamp}}"
  instance_type = "t4g.medium"
  region        = "us-east-1"
  source_ami    = data.amazon-ami.amazon-linux-latest.id
  ssh_username  = "ec2-user"
  # https://aws.amazon.com/blogs/mt/creating-packer-images-using-system-manager-automation/
  # https://developer.hashicorp.com/packer/integrations/hashicorp/amazon/latest/components/builder/ebs#iam-instance-profile-for-systems-manager
  ssh_interface        = "session_manager"
  communicator         = "ssh"
  iam_instance_profile = "cis-packer-build-policy-profile" # Adapted from TF SSM role for testing based on docs above

  vpc_filter {
    filters = {
      "isDefault" : "false"
    }
  }
  subnet_filter {
    filters = {
          "tag:Name": "packer-subnet"
    }
    random = false
  }
  # enforces imdsv2 support on the running instance being provisioned by Packer
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  imds_support = "v2.0" # enforces imdsv2 support on the resulting AMI
}

build {
  name = "Run Ansible and Shell Config"
  sources = [
    "source.amazon-ebs.cis"
  ]
  provisioner "shell" {
    inline = [
      "echo Connected via SSM at '${build.User}@${build.Host}:${build.Port}'",
      # We must set a root password for CIS to run
      format("echo 'root:%s' | sudo /usr/sbin/chpasswd -e", data.password.root.crypt),
      "sudo yum -y install amazon-cloudwatch-agent",
      # We accept the default dd agent version here
      "sudo DD_API_KEY=PREINSTALL DD_INSTALL_ONLY=true DD_SITE=datadoghq.com bash -c \"$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)\"",
      # Remove sshd since we only allow SSM per CIS 2.4
      "sudo yum remove -y openssh-server"
      "echo End of Shell Config via SSM"
    ]
  }
  provisioner "ansible" {
    use_proxy               =  false
    # We skip Level 2 and some deprecated packages
    extra_arguments         =  [ 
      "--skip-tags", "level2-server",
      "--skip-tags", "nftables",
      "--skip-tags", "firewalld",
      "--skip-tags", "rsyslog",
      "--skip-tags", "logrotate" 
      ]
    playbook_file           =  "AMAZON2023-CIS/site.yml"
    ansible_env_vars        =  ["PACKER_BUILD_NAME={{ build_name }}"]
    inventory_file_template =  "{{ .HostAlias }} ansible_host={{ .ID }} ansible_user=ec2-user ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand=\"sh -c \\\"aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p\\\"\"'\n"
  }
}
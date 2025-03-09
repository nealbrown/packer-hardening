# packer-hardening
CIS Control Packer Templates

Don't pay per-instance for CIS hardening.  Initial target platform is Amazon Linux 2023.

All credit for the ansible role goes to Ansible Lockdown https://github.com/ansible-lockdown/AMAZON2023-CIS

# Prereqs

Terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli

Packer https://developer.hashicorp.com/packer/tutorials/docker-get-started/get-started-install-cli

AWS CLI https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

AWS CLI SSM Plugin https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

Ansible

# Sample Interactive Ansible Usage on AL23 via SSM, just for testing the role

Note you must have your private key available or otherwise be able to auth via SSH to localhost as ec2-user

As root, set a root password

`passwd`

Then as ec2-user

`yum install ansible git`

`ansible-galaxy install git+https://github.com/ansible-lockdown/AMAZON2023-CIS.git`

`cd .ansible/roles/AMAZON2023-CIS`

`echo 'localhost' >> hosts` 

We must skip aide, firewalld, nftables, rsyslog, and logrotate since they are not available / deprecated
and in this example we only apply CIS Level 1

`ansible-playbook -i hosts --skip-tags level2-server,nftables,firewalld,rsyslog,logrotate site.yml`

# Provision Dedicated Packer VPC with roles and SSM endpoints

Prereq: AWS credentials available e.g. 

`aws configure` https://docs.aws.amazon.com/cli/latest/userguide/cli-authentication-user.html#cli-authentication-user-configure-wizard 

or

`aws-vault add default` https://github.com/99designs/aws-vault?tab=readme-ov-file#quick-start

Prereq: Terraform installed

Update the account number in the Packer role in `packer.tf` line 30.

`terraform init`

`terraform apply`

# Run Packer

Remove cloudwatch and/or datadog agent installs if not needed.  Set your playbook path on line 93- git command to clone the upstream project is above.

`packer build ansible.pkr.hcl`

Unfortunately it takes 20 minutes to run.  If Amazon deprecates more packages, it may be necessary to add further skips to the extra arguments starting on line 86.

If you need to remove sshd use `user-data` when you launch the instance- packer cannot do it natively since it breaks the ssh-over-ssm connection.

```
# Remove sshd since we only allow SSM per CIS 2.4
yum remove -y openssh-server
```

# Audit Mode Findings

It is expected to get a few audit mode findings at the end of the run, on a clean Amazon Linux 2023 AMI.  Evaluate these for your environment.  These include:

* [1.1.2.1] /tmp is not a separate partition
* [1.1.8.1] /dev/shm is not a separate partition
* [1.2.3] verify that you expect the Amazon Linux 2023 and Datadog yum repos to be in place
* [1.6.1.6] Ensure no unconfined (non-chroot) services exist
* [2.4] verify all running services are "necessary"
* [6.1.12] Ensure SUID and SGID files are reviewed


# Example of Yum Repo Audit Finding

```
"msg": [
    Run Ansible and Shell Config.amazon-ebs.cis:         "Warning!! Below are the configured repos. Please review and make sure all align with site policy",
    Run Ansible and Shell Config.amazon-ebs.cis:         [
    Run Ansible and Shell Config.amazon-ebs.cis:             "repo id                   repo name",
    Run Ansible and Shell Config.amazon-ebs.cis:             "amazonlinux               Amazon Linux 2023 repository",
    Run Ansible and Shell Config.amazon-ebs.cis:             "datadog                   Datadog, Inc.",
    Run Ansible and Shell Config.amazon-ebs.cis:             "kernel-livepatch          Amazon Linux 2023 Kernel Livepatch repository"
    Run Ansible and Shell Config.amazon-ebs.cis:         ]
    Run Ansible and Shell Config.amazon-ebs.cis:     ]
```

# Links

* https://developer.hashicorp.com/packer/integrations/hashicorp/amazon
* https://joshuajebaraj.com/posts/gcp-4/
* https://github.com/konstruktoid/hardened-images
* https://www.cisecurity.org/cis-hardened-images
* https://developer.hashicorp.com/packer/integrations/hashicorp/ansible/latest/components/provisioner/ansible

Alternate Approach using EC2 Image Builder pipeline https://github.com/aws-samples/deploy-cis-level-1-hardened-ami-with-ec2-image-builder-pipeline
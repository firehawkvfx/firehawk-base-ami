# The base AMI's primary purpose is to produce an anchor point with apt-get/yum updates, and apply bug fixes to incoming AMI's.
# Updates can be unstable on a daily basis so the base ami once successful can be reused, improving build time.
# Avoiding updates altogether is not good for security and some packages and executables depend on updates to function, so the update process is run initially here.
# Some AMI's may require fixes to resolves bugs which are also performed here (Centos 7, Open VPN).
# We also install any packages that will not likely require frequent modification (Python, Git).  If they do require significant/frequent/unreliable modification they do not belong here.


variable "aws_region" {
  type    = string
  default = null
}
variable "ami_role" {
  description = "A descriptive name for the purpose of the image."
  type        = string
}
variable "commit_hash" {
  description = "The hash of the commit in the current git repository contining this file."
  type        = string
}
variable "commit_hash_short" {
  description = "The hash of the commit in the current git repository contining this file."
  type        = string
}
variable "resourcetier" {
  description = "The current environment ( dev / green / blue / main )"
  type        = string
}

locals {
  timestamp    = regex_replace(timestamp(), "[- TZ:]", "")
  template_dir = path.root
  common_ami_tags = {
    "packer_template" : "firehawk-base-ami",
    "commit_hash" : var.commit_hash,
    "commit_hash_short" : var.commit_hash_short,
    "resourcetier" : var.resourcetier,
  }
}

source "amazon-ebs" "amazonlinux2-ami" {
  tags = merge(
    { "packer_source" : "amazon-ebs.amazonlinux2-ami" },
    { "Name" : "amazonlinux2_base_ami" },
    { "ami_role" : "amazonlinux2_base_ami" },
  local.common_ami_tags)
  ami_description = "An Amazon Linux 2 AMI with basic updates."
  ami_name        = "firehawk-base-amazonlinux2-${local.timestamp}-{{uuid}}"
  instance_type   = "t2.micro"
  region          = var.aws_region
  source_ami_filter {
    filters = {
      architecture                       = "x86_64"
      "block-device-mapping.volume-type" = "gp2"
      name                               = "*amzn2-ami-hvm-*"
      root-device-type                   = "ebs"
      virtualization-type                = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
  ssh_username = "ec2-user"

}

source "amazon-ebs" "amazonlinux2-nicedcv-nvidia-ami" {
  tags = merge(
    { "packer_source" : "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami" },
    { "Name" : "amazonlinux2_nicedcv_base_ami" },
    { "ami_role" : "amazonlinux2_nicedcv_base_ami" },
    local.common_ami_tags
  )
  ami_description = "A Graphical NICE DCV NVIDIA Amazon Linux 2 AMI with basic updates."
  # ami_name        = "firehawk-amazonlinux2-nicedcv-nvidia-ami-${local.timestamp}-{{uuid}}"
  ami_name = "firehawk-base-amazonlinux2-nicedcv-${local.timestamp}-{{uuid}}"
  # instance_type   = "g3s.xlarge" # Only required if testing a gpu.
  instance_type = "t2.micro"
  region        = var.aws_region
  source_ami_filter {
    # To update - query:
    # aws ec2 describe-images --filters Name=name,Values=DCV-AmazonLinux2-* --region $AWS_DEFAULT_REGION --query 'sort_by(Images, &CreationDate)[]'
    filters = {
      name = "DCV-AmazonLinux2-2020-2-9662-NVIDIA-450-89-x86_64"
    }
    most_recent = true
    owners      = ["877902723034"] # NICE DCV
  }
  ssh_username = "ec2-user"
}

# its possible to quire the latest ami with this filter
# aws ec2 describe-images \
#   --owners 679593333241 \
#   --filters \
#       Name=name,Values='CentOS Linux 7 x86_64 HVM EBS*' \
#       Name=architecture,Values=x86_64 \
#       Name=root-device-type,Values=ebs \
#   --query 'sort_by(Images, &Name)[-1].ImageId' \
#   --output text

source "amazon-ebs" "centos7-ami" {
  tags = merge(
    { "packer_source" : "amazon-ebs.centos7-ami" },
    { "Name" : "centos7_base_ami" },
    { "ami_role" : "centos7_base_ami" },
    local.common_ami_tags
  )
  ami_description = "A Cent OS 7 AMI with basic updates."
  ami_name        = "firehawk-base-centos7-${local.timestamp}-{{uuid}}"
  instance_type   = "t2.micro"
  region          = var.aws_region
  source_ami_filter {
    filters = {
      name             = "CentOS-7-*-*.x86_64-*"
      architecture     = "x86_64"
      root-device-type = "ebs"
      # product-code = "aw0evgkw8e5c1q413zgy5pjce"
    }
    most_recent = true
    owners      = ["679593333241"]
  }
  user_data_file = "${local.template_dir}/cloud-init.yaml" # This is a fix for some instance types with Centos 7 and mounts causing errors.
  ssh_username   = "centos"

}

source "amazon-ebs" "ubuntu18-ami" {
  tags = merge(
    { "packer_source" : "amazon-ebs.ubuntu18-ami" },
    { "Name" : "ubuntu18_base_ami" },
    { "ami_role" : "ubuntu18_base_ami" },
    local.common_ami_tags
  )
  ami_description = "An Ubuntu 18.04 AMI with basic updates."
  ami_name        = "firehawk-base-ubuntu18-${local.timestamp}-{{uuid}}"
  instance_type   = "t2.micro"
  region          = var.aws_region
  source_ami_filter {
    filters = {
      architecture                       = "x86_64"
      "block-device-mapping.volume-type" = "gp2"
      name                               = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"
      root-device-type                   = "ebs"
      virtualization-type                = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"

}

source "amazon-ebs" "base-openvpn-server-ami" {
  tags = merge(
    { "packer_source" : "amazon-ebs.base-openvpn-server-ami" },
    { "Name" : "openvpn_server_base_ami" },
    { "ami_role" : "openvpn_server_base_ami" },
    local.common_ami_tags
  )
  ami_description = "An Open VPN Access Server AMI with basic updates"
  ami_name        = "firehawk-base-openvpn-server-${local.timestamp}-{{uuid}}"
  instance_type   = "t2.micro"
  region          = var.aws_region
  user_data       = <<EOF
#! /bin/bash
admin_user=openvpnas
admin_pw=''
EOF
  source_ami_filter {
    filters = {
      description  = "OpenVPN Access Server 2.11.3 publisher image from https://www.openvpn.net/."
      product-code = "f2ew2wrz425a1jagnifd02u5t"
    }
    most_recent = true
    owners      = ["679593333241"]
  }
  ssh_username = "openvpnas"

}

build {
  sources = [
    "source.amazon-ebs.ubuntu18-ami",
    "source.amazon-ebs.amazonlinux2-ami",
    "source.amazon-ebs.amazonlinux2-nicedcv-nvidia-ami",
    "source.amazon-ebs.centos7-ami",
    "source.amazon-ebs.base-openvpn-server-ami",
  ]

  ### Wait for cloud init ###

  provisioner "shell" {
    inline = [
      "echo 'Init success.'",
      "sudo echo 'Sudo test success.'",
      "unset HISTFILE",
      "history -cw",
      "echo === Waiting for Cloud-Init ===",
      "timeout 180 /bin/bash -c 'until stat /var/lib/cloud/instance/boot-finished &>/dev/null; do echo waiting...; sleep 6; done'",
    ]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang   = "/bin/bash -e"
  }

  ### Wait for apt daily update ###

  provisioner "shell" {
    inline = [
      "echo === System Packages ===",
      "echo 'Connected success. Wait for updates to finish...'", # Open VPN AMI runs apt daily update which must end before we continue.
      "sudo systemd-run --property='After=apt-daily.service apt-daily-upgrade.service' --wait /bin/true; echo \"exit $?\""
    ]
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline_shebang   = "/bin/bash -e"
    only             = ["amazon-ebs.ubuntu18-ami", "amazon-ebs.base-openvpn-server-ami"]
  }

  ### Ensure openvpnas user is owner of their home dir to firx Open VPN AMI bug

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "export SHOWCOMMANDS=true; set -x",
      "sudo cat /etc/systemd/system.conf",
      "sudo chown openvpnas:openvpnas /home/openvpnas; echo \"exit $?\"",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections; echo \"exit $?\"",
    ]
    inline_shebang = "/bin/bash -e"
    only           = ["amazon-ebs.base-openvpn-server-ami"]
  }

  ### Ensure Dialog is installed to fix open vpn image issues ###

  provisioner "shell" {
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    valid_exit_codes = [0, 1] # ignore exit code.  this requirement is a bug in the open vpn ami.
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install dialog; echo \"exit $?\"", # supressing exit code - until dialog is installed, apt-get may produce non zero exit codes. In open vpn ami
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -q; echo \"exit $?\""
    ]
    inline_shebang = "/bin/bash -e"
    only           = ["amazon-ebs.base-openvpn-server-ami"]
  }

  ### Update ###

  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get update -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install dpkg -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get --yes --force-yes -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" upgrade", # These args are required to fix a dpkg bug in the openvpn ami.

    ]
    only = ["amazon-ebs.ubuntu18-ami", "amazon-ebs.base-openvpn-server-ami"]
  }
  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "sudo yum update -y"
    ]
    only = ["amazon-ebs.amazonlinux2-ami", "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami", "amazon-ebs.centos7-ami"]
  }

  ### GIT ###

  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sleep 5",
      "export CENTOS_MAIN_VERSION=$(cat /etc/centos-release | awk -F 'release[ ]*' '{print $2}' | awk -F '.' '{print $1}')",
      "echo $CENTOS_MAIN_VERSION",                                                         # output should be "6" or "7"
      "sudo yum install -y https://repo.ius.io/ius-release-el$${CENTOS_MAIN_VERSION}.rpm", # Install IUS Repo and Epel-Release:
      "sudo yum install -y epel-release",
      "sudo yum erase -y git*", # re-install git:
      "sudo yum install -y git-core",
      "git --version"
    ]
    only = ["amazon-ebs.centos7-ami"]
  }
  provisioner "shell" {
    inline = [
      "sudo yum install -y git",
      "git --version"
    ]
    only = ["amazon-ebs.amazonlinux2-ami", "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami"]
  }

  ### Python 3 & PIP ###

  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -y install python3 python-apt unzip jq wget",
      "sudo apt install -y python3-pip",
      "python3 -m pip install --upgrade pip",
      "python3 -m pip install boto3",
      "python3 -m pip --version",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git",
      "echo '...Finished bootstrapping'"
    ]
    only = ["amazon-ebs.ubuntu18-ami", "amazon-ebs.base-openvpn-server-ami"]
  }
  provisioner "shell" {
    inline = [
      "sudo yum install -y python python3.10 python3-pip unzip jq wget",
      "python3 -m pip install --user --upgrade pip",
      "python3 -m pip install --user boto3"
    ]
    only = ["amazon-ebs.amazonlinux2-ami", "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami", "amazon-ebs.centos7-ami"]
  }

  # install nebula dependencies
  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    inline = [
      "sudo yum install -y unzip wget nmap-ncat"
    ]
    only = ["amazon-ebs.amazonlinux2-ami", "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami", "amazon-ebs.centos7-ami"]
  }

  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    inline = [
      "sudo apt-get install -y unzip wget netcat-openbsd"
    ]
    only = ["amazon-ebs.ubuntu18-ami"]
  }


  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    inline = [
      "echo \"Installing Nebula...\"",
      "set -x; sudo mkdir -p /etc/nebula",
      "set -x; sudo chmod 777 /etc/nebula",
      "set -x; cd /etc/nebula",
      "set -x; sudo wget -P /tmp https://github.com/slackhq/nebula/releases/download/v1.8.2/nebula-linux-amd64.tar.gz > /dev/null",
      "set -x; sudo mv -f /tmp/nebula-linux-amd64.tar.gz /etc/nebula/nebula-linux-amd64.tar.gz",
      "set -x; sudo tar -xvf nebula-linux-amd64.tar.gz",
      "set -x; sudo rm -f nebula-linux-amd64.tar.gz",
      "set -x; sudo chmod 700 /etc/nebula/nebula-cert",
      "set -x; sudo chmod 700 /etc/nebula/nebula",
    ]
    only = [
      "amazon-ebs.centos7-ami",
      "amazon-ebs.ubuntu18-ami",
      "amazon-ebs.amazonlinux2-ami",
      "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami"
    ]
  }

  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    ### AWS CLI
    inline = [
      # "python3 -m pip install --user --upgrade awscli",
      "if [[ -n \"$(command -v yum)\" ]]; then sudo yum remove awscli -y; fi",         # uninstall AWS CLI v1
      "if [[ -n \"$(command -v apt-get)\" ]]; then sudo apt-get remove awscli -y; fi", # uninstall AWS CLI v1
      "if sudo test -f /bin/aws; then sudo rm -f /bin/aws; fi",                        # Ensure AWS CLI v1 doesn't exist
      "curl \"https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.5.4.zip\" -o \"awscliv2.zip\"",
      "unzip -q awscliv2.zip",
      "sudo ./aws/install -b /usr/local/bin",
      "aws --version"
    ]
    only = [
      "amazon-ebs.centos7-ami",
      "amazon-ebs.amazonlinux2-nicedcv-nvidia-ami", # already installed.  otherwise need to silence error
      "amazon-ebs.amazonlinux2-ami",
      "amazon-ebs.base-openvpn-server-ami",
      "amazon-ebs.ubuntu18-ami"
    ]
  }

  # Upgrade kernel for centos 7 - may be needed for Nebula to function
  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "sudo yum install kernel -y"
    ]
    only = ["amazon-ebs.centos7-ami"]
  }

  ### Cleanup
  provisioner "shell" {
    inline_shebang   = "/bin/bash -e"
    environment_vars = ["DEBIAN_FRONTEND=noninteractive"]
    inline = [
      "sudo rm -fr /tmp/*"
    ]
  }

  post-processor "manifest" {
    output     = "${local.template_dir}/manifest.json"
    strip_path = true
    custom_data = {
      timestamp = "${local.timestamp}"
    }
  }
}

![N|Solid](./images/terraform2.png)
<br /><br />
AWS'de Master ve Worker sunucularımızı terraform ile yapıyoruz. Terraform ile aşağıdaki resource'ları oluşturuyoruz.
- Vpc
- Subnet
- Internet Gateway
- Route Table
- EC2
- Security Group
- PEM file
- ECR
<br /><br />

### ``` provider.tf ```
Aws'de kullanacağım region ve profilimi belirtiyorum. Profileriniz görmek için ```cat /Users/oguz/.aws/credentials ``` diyerek görebilirsiniz. Burada ki komutu kendinize göre düzenlemeniz gerek.
```sh
  provider "aws" {
    region = "eu-west-1"
    profile = "terraform"
  }
```
<br /><br />

### ``` vars.tf ```
Terraform scriptlerimizde kullanacağımız değişkenleri burada tanımlıyoruz. Ben kullanacağım ami_id, instance_type ve docker registry(ECR) bilgilerini burada tuttum.
```sh
variable "aws_ami_id" {
    type = string
    default = "ami-0f03fd8a6e34800c0"
    description = "Canonical, Ubuntu, 18.04 LTS, amd64 bionic image build on 2022-05-26"
  
}

variable "instance_type" {
    type = string
    default = "t3.medium"
}

variable "ecr_name" {
   type = string
   default = "pythonappregistry"
}

```

<br /><br />

### ``` ecr.tf ```
Build adımında oluşturacağımız docker registry'i oluşturuyoruz.
```sh
resource "aws_ecr_repository" "pythonapp-repository" {
  name                 = var.ecr_name
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "pythonapp-repository-policy" {
  repository = aws_ecr_repository.pythonapp-repository.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "adds full ecr access to the python repository",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}
```

<br /><br />

### ``` vpc.tf ```
EC2'ların kullanacağı vpc'leri oluşturuyoruz. Hangi ip aralıklarında ip alacağı gibi bilgileri burada tanımlıyoruz.
```sh
# Create VPC
resource "aws_vpc" "k8s_vpc" {
  cidr_block       = "10.0.0.0/16"
  enable_dns_hostnames=true
  enable_dns_support =true
  tags = {
    Name = "K8S VPC"
  }
}
# Create Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.k8s_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-west-1a"
  tags = {
    Name = "Public Subnet"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "k8s_gw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    Name = "K8S GW"
  }
}
# Create Routing table
resource "aws_route_table" "k8s_route" {
    vpc_id = aws_vpc.k8s_vpc.id
    
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.k8s_gw.id
    }
        
        tags = {
            Name = "K8S Route"
        }
}
# Associate Routing table
resource "aws_route_table_association" "k8s_asso" {
    subnet_id = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.k8s_route.id
}

```

<br /><br />

### ``` securitygroup.tf ```
EC2'ların giriş ve çıkış(igress/egress) kurallarını belirtiyoruz.
```sh
# Create security group
resource "aws_security_group" "allow_ssh_http" {
  name        = "Web_SG"
  description = "Allow SSH and HTTP inbound traffic"
  vpc_id      = aws_vpc.k8s_vpc.id
  ingress {
    description      = "Allow All"
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = [ "0.0.0.0/0" ]
  }
  ingress {
    description      = "Allow All"
    from_port        = 0
    to_port          = 0
    protocol         = -1
    cidr_blocks      = [ "0.0.0.0/0" ]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  tags = {
    Name = "K8S SG"
  }
}
```

<br /><br />

### ```sshkey.tf```
EC2'lara ssh ile bağlanmamız için gerekli pem dosyasını oluşturuyoruz. Burada kullanacağı şifreleme algoritması gibi bilgilerini giriyoruz. Ansible'da bu pem dosyasını kullanacak.
local_file diyerek oluşturduğumuz pem dosyasını root path'imize indiriyoruz.
```sh
# Provides EC2 key pair
resource "aws_key_pair" "terraformkey" {
  key_name   = "terraform_key"
  public_key = tls_private_key.k8s_ssh.public_key_openssh
}

# Create (and display) an SSH key
resource "tls_private_key" "k8s_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
# Create local key
resource "local_file" "keyfile" {
    content         = tls_private_key.k8s_ssh.private_key_pem
    filename        = "terraform_key.pem"
    file_permission = "0400"
}
```

<br /><br />

### ``` masternode.tf ```
Master olarak kullanacağımız EC2'nun kullanacağı ami,instance_type ve key_name gibi değişkenlerini tanımlıyoruz.
```sh
# Launch EC2 instnace for Master Node
resource "aws_instance" "k8smaster" {
  ami                   = var.aws_ami_id
  instance_type         = var.instance_type
  key_name              = aws_key_pair.terraformkey.key_name
  associate_public_ip_address = true
  subnet_id             = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [ aws_security_group.allow_ssh_http.id ] 
  tags = {
    Name = "Master Node"
  }
}
```

<br /><br />

### ``` workernode.tf ```
Worker olarak kullanacağımız EC2'nun kullanacağı ami,instance_type ve key_name gibi değişkenlerini tanımlıyoruz.
```sh
# Launch EC2 instnace for Worker Node
resource "aws_instance" "k8sworker" {
  ami                   = var.aws_ami_id
  instance_type         = var.instance_type
  key_name              = aws_key_pair.terraformkey.key_name
  associate_public_ip_address = true
  subnet_id             = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [ aws_security_group.allow_ssh_http.id ] 
  tags = {
    Name = "Worker Node"
  }
}
```
<br /><br/>

### ```masterrole.tf```
Master sunucumuza aws servislerini kullanabilmesi için gerekli yetlileri tanımlıyoruz.
```sh
resource "aws_iam_role" "master_role" {
  name = "master_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      role = "master"
  }
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "master_profile"
  role = "${aws_iam_role.master_role.name}"
}

resource "aws_iam_role_policy" "master_policy" {
  name = "master_policy"
  role = "${aws_iam_role.master_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*",
                "elasticloadbalancing:*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
```
<br /><br />

### ```workerrole.tf```
Worker sunucumuza aws servislerini kullanabilmesi için gerekli yetlileri tanımlıyoruz.
```sh
resource "aws_iam_role" "worker_role" {
  name = "worker_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
      role = "worker"
  }
}

resource "aws_iam_instance_profile" "worker_profile" {
  name = "worker_profile"
  role = "${aws_iam_role.worker_role.name}"
}

resource "aws_iam_role_policy" "worker_policy" {
  name = "worker_policy"
  role = "${aws_iam_role.worker_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:Describe*",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:BatchGetImage"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
```


<br /><br/>

### ``` ansible.tf ```
Ansible'ın kullanacağı invertory yani sunucularımız ip'lerinin olduğu dosyayı burada oluşturuyoruz.
Local-exec ile ansible scriptimizi tetikleyerek EC2'lara kubernetes kurulumu yapıyoruz.


``` invertory```
```sh
[Master_Node]
34.54.65.76
[Worker_Node]
34.54.65.77
```
```sh
# Update Ansible inventory
resource "local_file" "ansible_host" {
    depends_on = [
      aws_instance.k8smaster
    ]
    content     = "[Master_Node]\n${aws_instance.k8smaster.public_ip}\n\n[Worker_Node]\n${aws_instance.k8sworker.public_ip}"
    filename    = "inventory"
  }
# Run Ansible playbook 
resource "null_resource" "null1" {
    depends_on = [
      local_file.ansible_host
    ]
  provisioner "local-exec" {
    command = "sleep 60"
    }
  provisioner "local-exec" {
    command = "ansible-playbook ansibletasks.yaml"
    }
}
```
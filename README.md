# Python Simple App Deploy Kubernetes

> Python web uygulamamızı deploy edeceğiz. Terraform ile AWS'de Master ve Worker olacak şekilde 2 tane EC2 ayağa kaldıracağız. Daha sonra bu EC2'lara ansible yardımı ile kubernetes'i kuracağız.

<br /><br />
![N|Solid](./images/teranec2.png)
<br /><br />
# Gereksinimler
- Terraform
- Ansible
- Aws Account
- AwsCLI
- Helm3
<br /><br />
---
![N|Solid](./images/docker.png)
<br /><br />
## Python Uygulamasının Dockerize Edilmesi

```docker
FROM python:alpine3.15
RUN mkdir /app
WORKDIR /app

RUN apk update \
    && apk add --virtual build-deps gcc python3-dev musl-dev \
    && apk add --no-cache mariadb-dev

COPY requirements.txt requirements.txt
RUN pip3 install -r requirements.txt
RUN apk del build-deps
COPY . .
#CMD ["python", "app.py"]
RUN chmod +x ./entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
```

- ## ``` requirements.txt ```

Bu dosyada uygulamamızın ihtiyaç duyduğu paketleri alt alta yazıyor. pip3 komutu tek tek okuyup bizim için indiriyor.

- ## ``` Gunicorn ```
Python ile yazılmış bir WSGI HTTP server. Dinamik içerik söz konusu olduğunda Apache’ye göre daha lightweight bir web server olduğu için performansı daha yüksek. Daha fazla detay için http://gunicorn.org/


----

### İlk build sırasında aşağıdaki hatayla karşılaştım. Bunu için Dockerfile'da değişiklik yapmam gerekti.

<br /><br />

```diff
- #9 4.532 Collecting mysqlclient                                                             
- #9 4.572   Downloading mysqlclient-2.1.0.tar.gz (87 kB)
- #9 4.589      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 87.6/87.6 KB 6.1 MB/s eta 0:00:00
- #9 4.624   Preparing metadata (setup.py): started
- #9 5.102   Preparing metadata (setup.py): finished with status 'error'
- #9 5.110   error: subprocess-exited-with-error
- #9 5.110   
- #9 5.110   × python setup.py egg_info did not run successfully.
- #9 5.110   │ exit code: 1
- #9 5.110   ╰─> [16 lines of output]
- #9 5.110       /bin/sh: mysql_config: not found
- #9 5.110       /bin/sh: mariadb_config: not found
- #9 5.110       /bin/sh: mysql_config: not found
- #9 5.110       Traceback (most recent call last):
- #9 5.110         File "<string>", line 2, in <module>
- #9 5.110         File "<pip-setuptools-caller>", line 34, in <module>
- #9 5.110         File "/tmp/pip-install-_4a3fl2d/mysqlclient_ab08a5bdc80e4db0ad0b0d86569c9ced/setup.py", line 15, in <module>
- #9 5.110           metadata, options = get_config()
- #9 5.110         File "/tmp/pip-install-_4a3fl2d/mysqlclient_ab08a5bdc80e4db0ad0b0d86569c9ced/setup_posix.py", line 70, in get_config
- #9 5.110           libs = mysql_config("libs")
- #9 5.110         File "/tmp/pip-install-_4a3fl2d/mysqlclient_ab08a5bdc80e4db0ad0b0d86569c9ced/setup_posix.py", line 31, in mysql_config
- #9 5.110           raise OSError("{} not found".format(_mysql_config_path))
- #9 5.110       OSError: mysql_config not found
- #9 5.110       mysql_config --version
- #9 5.110       mariadb_config --version
- #9 5.110       mysql_config --libs
- #9 5.110       [end of output]
- #9 5.110   
- #9 5.110   note: This error originates from a subprocess, and is likely not a problem with pip.
- #9 5.113 error: metadata-generation-failed
```

### Aşağıdaki kod blogunu ekleyerek build alabildim.
```diff
+ RUN apk update \
+   && apk add --virtual build-deps gcc python3-dev musl-dev \
+    && apk add --no-cache mariadb-dev
+ RUN apk del build-deps
```

----

Gunicorn ile uygulamayı ayağa kaldırmak için aşağıdaki entrypoint.sh dosyasını oluşturdum ve executable yetkisi olan chmod +x verdim.

```sh
#!/bin/sh
gunicorn app:application -w 4 --threads 2 -b 0.0.0.0:3000
```
---


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

<br /><br />

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


<br /><br />

![N|Solid](./images/ansible.png)



Terraform ile oluşturduğumuz EC2'lara gerekli kurulumları yapacak aracımız, Ansible. Tekrarlı işlemlerinizi 'n' tane sunucularında hızlıca yapabilirsiniz. 

Örnek olarak; 100 tane ubuntu sunucu var. Bir güvenlik paketi güncellemesi yapacaksınız. Ansible ile tek bir script ile tüm sunucularınızda güvenlik paketinizi yükleyebilirsiniz.

<br /><br />

### ``` ansible.cfg ```
Ansible'ın kullanacağı config'ini aşağıdaki gibi belirtiyoruz.
private_key_file=terraform_key.pem, yukarıda terraform ile oluşturuduğumuz pem dosyasının adını burada belirtiyoruz.
```sh
[defaults]
inventory=inventory
roles_path=roles/
host_key_checking=False
ask_pass=False
remote_user=ubuntu
private_key_file=terraform_key.pem

[privilege_escalation]
become=True
become_user=root
become_method=sudo
become_ask_pass=False
```

<br /><br />

###  ```ansibletasks.yaml ```
Aşağıdaki adımları hem Master hemde Worker node'larda çalıştıracak. Çünkü aşağıdaki paketler ikisi içinde gerekli.
```yaml
# Install required software
- hosts: Master_Node:Worker_Node
  become: yes
  tasks:
   - name: Get Kubernetes apt-key
     apt_key:
       url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
       state: present

   # Note: currently the latest repository is still xenial not bionic
   - name: Add Kubernetes APT repository
     apt_repository:
      repo: deb http://apt.kubernetes.io/ kubernetes-xenial main
      state: present
      filename: 'kubernetes'
      
   # Install packages
   - name: Install required software
     apt: 
       name: "{{ packages }}"
       update_cache: true
       state: present
     vars:
       packages:
       - docker.io
       - kubelet
       - kubeadm

   # Docker service is disabled by default
   - name: enable Docker service
     systemd:
       name: docker
       enabled: yes

```
<br /><br />

Master Node'a kubectl kuruyoruz
```yaml
# Setup Cluster
- hosts: Master_Node
  become: yes
  tasks:
   - name: Install kubectl on Master
     apt:
       name: kubectl
       state: present
```
<br /><br />

kubeadm ile kubernetes'i başlatıyoruz.
```yaml
   # Initialize Cluster. The log is also used to prevent an second initialization
   - name: Initialize Cluster
     shell: kubeadm init --pod-network-cidr=10.244.0.0/16 >> cluster_init.log
     args:
       chdir: $HOME
       creates: cluster_init.log
```
<br /><br />

kubectl komutunu çalıştırdığımızda default olarak $HOME/.kube/config doyasına bakar. Aşağıda $HOME/.kube dosyasını oluşturuyoruz. Bir sonraki adımda config dosyamızı buraya kopyalacağız.
```yaml
   # Create the configuration / configuration directory
   - name: Create .kube directory
     file:
       path: $HOME/.kube
       state: directory
       mode: 0755
```
<br /><br />

/etc/kubernetes/admin.conf path'inde oluşan admin.conf dosyasını yukarıda oluşturduğumuz path'e config olarak kopyalıyoruz.
```yaml
   - name: Copy admin.conf to the user's kube directory
     copy:
       src: /etc/kubernetes/admin.conf
       dest: $HOME/.kube/config
       remote_src: yes
```
<br /><br />

Kubernetes container'larının arasındaki network'ü sağlayacak olan flannel'ı kuruyoruz.
```yaml
   - name: Setup Flannel. Use log to prevent second installation
     shell: kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml >> flannel_setup.log
     args:
       chdir: $HOME
       creates: flannel_setup.log
```
<br /><br />

Uygulamalarımızda persistence volume kullanabilmek için AWS EBS storageclass kurulumu yapıyoruz.
```yaml
   - name: Setup StorageClass
     shell: kubectl apply -f https://gist.githubusercontent.com/oguzzarci/7c22f218171e59e3529f9a04208a7d10/raw/28976bcb28c46ac6208ddd3b6f51988b5b7579bd/storageclass.yaml >> storage_class.log
     args:
       chdir: $HOME
       creates: storage_class.log
```
<br /><br />

Worker olacak sunucuyu cluster'a join edecek komutu oluşturuyoruz. join_commad değişkenine atıyoruz.
```yaml
   - name: Create token to join cluster
     shell: kubeadm token create --print-join-command
     register: join_command_raw

   - name: Set join command as fact
     set_fact:
       join_command: "{{ join_command_raw.stdout_lines[0] }}"
```
<br /><br />

Local bilgisayarımızdan bağlanabilmek için admin.conf dosyasını kopyalıyoruz.
```yaml
   - name: Copy KubeConfig to Local
     fetch:
       src: /etc/kubernetes/admin.conf
       dest: ./
       flat: yes
```
<br /><br />

Yukarıda oluşturduğumuz join_command'ı Worker Node'a kullanaracak kubernetes cluster'ına worker olarak ekliyoruz.
```yaml
# Join Cluster with each kube-node
- hosts: Worker_Node
  become: yes
  tasks:

    - name: join_command
      debug: var=join_command

    - name: Set master IP
      set_fact:
        master_ip: "{{ groups['Master_Node'][0] }}"

    - name: Wait for master's port 6443
      wait_for: "host={{ groups['Master_Node'][0] }} port=6443 timeout=1"

    - name: Join the cluster. Use log to prevent joining twice
      shell: "{{ hostvars[master_ip].join_command }} >> node_join.log"
      args:
        chdir: $HOME
        creates: node
```

<br /><br />

# SETUP
> Terraform scriptlerimizin olduğu yerde aşağıdaki komutları sırasıyla çalıştıracağız.
- terraform init
- terraform validate
- terraform plan
- terraform appy ve terraform apply --auto-approve

<br /><br />

### ``` terrraform init : ``` Scriptlerimizde kullandığımız modülleri indiriyor. Örnek olarak; npm install
![N|Solid](./images/terraforminit.png)

<br /><br />

### ```  terraform validate :```  Yazdığımız scriptlerde herhangi bir hata olup olmadığını kontrol ediyoruz.

![N|Solid](./images/terraformvalidate.png)

<br /><br />

### ``` terraform plan :``` Terraform'un bizim için neler oluşturacağını görüyoruz. Oluşturmadan önce kontrol edebiliyoruz.

![N|Solid](./images/terraformplan.png)

<br /><br />

### ``` terraform apply :``` Bu komut ile tüm resource'lar oluşmaya başlayacaktır. Ama sizden bir onay isteyecektir. yes diyerek devam edebilirsiniz.

![N|Solid](./images/terraformapply.png)

<br /><br />

### ``` terraform apply --auto--approve :``` Bu komut ile tüm resource'lar oluşmaya başlayacaktır. Sizden onay beklemez ve tüm resource'lar oluşmaya başlar.
---
![N|Solid](./images/devops.png)

<br /><br />

> ```terraform apply```'dan sonra ```yes``` diyerek kurulumlara başlıyoruz.



Aşağıdaki görüntüde terraform master ve worker node'ları oluşturdu. local-exec adıma geldi burada da ansible scriptimizi tetikleyecek.
![N|Solid](./images/setup.png)

<br /><br />

```Ansible``` çalışarak node'lara gerekli kurulumları yapıyor.

![N|Solid](./images/setup2.png)

<br /><br />

Kurulumlar tamamlandı ve output olarak tanımladığımız Master ve Worker node'larının public ip'leri döndü. Terraform toplamda 15 tane resource oluşturuğunu bilgisinide veriyor.

![N|Solid](./images/setup3.png)

<br /><br />

---

![N|Solid](./images/k8s.png)

<br /><br />

# SSH MASTER NODE

Terraform output olarak bize Master ve Worker node'ların public ip'leri veriyor. Oluşturduğumuz .pem dosyası ile bu sunuculara kolaylıkla ssh ile bağlanabiliriz.

Aşağıdaki ssh komutu ile sunucuya bağlanalım.
<br /><br />
```sh
ssh -i terraform_key.pem ubuntu@PUBLIC_IP
```
<br /><br />
![N|Solid](./images/ssh.png)
<br /><br />
Kurulumları root kullanıcı ile yaptığımız için ilk olarak root kullanıcına geçmemiz gerekiyor. Daha sonra ```kubectl get nodes``` diyerek kontrollerimizi gerçekleştiriyoruz.
<br /><br />

![N|Solid](./images/ssh2.png)
<br /><br />
Kubernetes kurulumumuz sorunsuz bir şekilde tamamlanmış.

<br /><br />

# Oluşan Resource'lar
>EC2
![N|Solid](./images/nodes.png)

>VPC
![N|Solid](./images/vpc.png)


>Subnet
![N|Solid](./images/subnet.png)

>Security Group
![N|Solid](./images/sg.png)

>Key pair
![N|Solid](./images/key.png)

>Amazon Elastic Container Registry (ECR)
![N|Solid](./images/ecr.png)

---
<br /><br />

# AZURE DEVOPS İLE CI/CD
### Gereksinimler
- Microsof Hesabı(adiniz@hotmail.com vs)

<br /><br />

## ```Build Pipeline```

> Kodlarımız github'da olacak, build alıp AWS ECR'a pushlayacağız. ```BuildId``` ile uygulamamızı versiyonlayacağız.

### Aşamalar
- AzureDevOps'da proje açılması
- Aws için service connection girilmesi
- Docker Build
- ECR Push

---

<br /><br />
```AzureDevOps'da proje açılması```
> Sol üstte New project butonuna tıkladıktan sonra proje ismini belirleyip oluşturuyoruz. 

![N|Solid](./images/createnewproject.png)

![N|Solid](./images/newproject.png)

<br /><br />

```Aws için service connection girilmesi```
> Oluşturduğumuz projeye tıkladıktan sonra sol alttan Project settings daha sonra Service connection'u seçiyoruz.

![N|Solid](./images/projectsettings.png)

![N|Solid](./images/serviceconnections.png)

![N|Solid](./images/newserviceconnection.png)

> Aşağıdaki gibi eğer AWS seçeneği görünmüyorsa AWS plugin'i yüklenmesi gerekiyor. Aşağıdaki adımları izleyerek hızlıca yükleyebilirsiniz.

1. Organization settings
2. Extensions
3. Browse marketplace
4. Search AWS

![N|Solid](./images/pg.png)

5. Plugin'e tıkladıktan sonra ```Get it free ```diyerek devam ediyoruz.

Eklemek istediğimiz organizasyonu seçecerek ``ìnstall`` diyerek devam ediyoruz.

![N|Solid](./images/ipg.png)

![N|Solid](./images/ipg.png)

<br /><br />

> Service connection ekranına tekrar geldiğinizde AWS seçeneğinin geldiğini göreceksiniz.

![N|Solid](./images/scaws.png)

Next diyerek ilerlediğimizde sizden ```Access Key ID```, ```Secret Access Key``` ve ```Service connection name``` isteyecek. Bu alanlar zorunludur.

AWS IAM üzerinden ECR'da full yetkili bir kullanıcı oluşturduktan sonra bu kullanıcının bilgilerini kullanabilirsiniz. 

![N|Solid](./images/ecrok.png)

<br /><br />

```Docker Build```
> Proje sayfasında sol sekmede bulunan Pipelines kısmından Create Pipeline diyerek yeni bir pipeline oluşturuyoruz.

![N|Solid](./images/pipeline.png)

Kodlarımız github da olacağı için aşağıdaki ```Authorize using OAuth```butonuna tıklayarak gerekli yetkileri tanımlıyoruz.

![N|Solid](./images/pipeline2.png)

![N|Solid](./images/pipeline3.png)

![N|Solid](./images/pipeline4.png)

Continue diyerek devam ediyoruz.
```Select a template``` kısmı için Empty Job diyerek devam ediyoruz.

![N|Solid](./images/pipeline5.png)

Yukarıdaki ekranı gördükten sonra soldan Docker ve Amazon ECR Push pluginlerini ekliyoruz.

![N|Solid](./images/pipeline6.png)

Ekledikten sonra aşağıdaki gibi pipeline'mızı düzenliyoruz.

![N|Solid](./images/pipeline8.png)

> Build almak için yukarıdaki Save & queue diyerek ilk build'mizi başlatıyoruz.

![N|Solid](./images/pipeline9.png)

Build başarılı bir şekilde çalıştı ve ECR'a pushladık.

![N|Solid](./images/pipeline10.png)

![N|Solid](./images/pipeline11.png)

> Kodumuza her push çıktığımızda build almasını istiyorsak aşağıdaki gibi ```trigger```'ı açmamız gerekiyor.

![N|Solid](./images/pipeline12.png)


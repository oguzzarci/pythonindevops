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
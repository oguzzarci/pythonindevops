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
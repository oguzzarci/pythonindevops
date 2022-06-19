# Print K8s Master and Worker node IP
output "Master_Node_IP" {
  value = aws_instance.k8smaster.public_ip
}
output "Worker_Node_IP" {
  value = aws_instance.k8sworker.public_ip
}
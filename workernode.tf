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
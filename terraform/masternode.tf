# Launch EC2 instnace for Master Node
resource "aws_instance" "k8smaster" {
  ami                   = var.aws_ami_id
  instance_type         = var.instance_type
  iam_instance_profile = "${aws_iam_instance_profile.master_profile.name}"
  key_name              = aws_key_pair.terraformkey.key_name
  associate_public_ip_address = true
  subnet_id             = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [ aws_security_group.allow_ssh_http.id ] 
  tags = {
    Name = "Master Node"
  }
}
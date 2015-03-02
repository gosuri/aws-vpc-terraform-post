/* web server */
resource "aws_instance" "app" {
  ami = "ami-049d8641"
  instance_type = "t2.small"
  subnet_id = "${aws_subnet.private.id}"
  security_groups = ["${aws_security_group.default.id}"]
  key_name = "${aws_key_pair.deployer.key_name}"
  source_dest_check = false
  tags = { 
    Name = "app"
  }
  /* connection { */
  /*   user = "ubuntu" */
  /*   key_file = "ssh/insecure-deployer" */
  /* } */
  /* provisioner "remote-exec" { */
  /*   inline = [ */
  /*     "curl -sSL https://get.docker.com/ubuntu/ | sudo sh" */
  /*   ] */
  /* } */
}

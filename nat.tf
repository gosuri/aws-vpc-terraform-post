/* NAT/VPN server */
resource "aws_instance" "nat" {
  ami = "ami-049d8641"
  instance_type = "t2.small"
  subnet_id = "${aws_subnet.public.id}"
  security_groups = ["${aws_security_group.default.id}", "${aws_security_group.nat.id}"]
  key_name = "${aws_key_pair.deployer.key_name}"
  source_dest_check = false
  tags = { 
    Name = "nat"
  }
  connection {
    user = "ubuntu"
    key_file = "ssh/insecure-deployer"
  }
  provisioner "remote-exec" {
    inline = [
      "curl -sSL https://get.docker.com/ubuntu/ | sudo sh",
      "sudo iptables -t nat -A POSTROUTING -j MASQUERADE",
      "echo 1 > /proc/sys/net/ipv4/conf/all/forwarding",
      "sudo mkdir -p /etc/openvpn",
      "sudo docker run --name ovpn-data -v /etc/openvpn busybox",
      "sudo docker run --volumes-from ovpn-data --rm kylemanna/openvpn ovpn_genconfig -p 10.128.0.0/16 -u udp://${aws_instance.nat.public_ip}"
    ]
  }
}

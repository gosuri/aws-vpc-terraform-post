Guide to automating a multi-tiered application securely on AWS with Docker and Terraform.
=======================================================================================

Data is particularly vulnerable while it is traveling over the Internet, securing the transporation of the data is the most fundamental component to a secure network. 

By hosting your crutial network resources such as databases and applicaiton servers in private network will lay a foundation to build such a network.

The Goal of the guide is to help you a build private network on AWS and provide you a secure way to access them using a VPN. 

The scope is limited to building secure network and does not cover application and OS level security.

Architecture
------------

We will essentially be building a Virtual Private Cloud (VPC) on AWS with public and a private subnets(sub-networks). Instances in the private subnet can't access the internet directly thereby making the private subnet an ideal place for application and database servers. The private subnet will comprise of application and database instances along with any other support resource(s) required to serve your application such as caching, build servers, configuration stores etc. Instances in the private subnet rely on a Network Address Translation (NAT) server running in the public subnet to connect to the internet. All Instances in the public subnet can transmit inbound and outbount traffic from the internet, the routing resources such as load balancers, vpn and nat servers reside in this subnet. 

The NAT server will also run a VPN server running OpenVPN, a full-featured SSL VPN which implements OSI layer 3 secure network extension using the industry standard SSL/TLS protocol over a UDP encapsulated network.

Connection to the VPN server can be established using any OpenVPN client. On a Mac, you could use [Viscocity](https://www.sparklabs.com/viscosity) is a good commercial client, or an opensource client [Tunnelblick for Mac](https://code.google.com/p/tunnelblick/). Clients are for other operating system are listed on the [openvpn clients page](https://openvpn.net/index.php/access-server/docs/admin-guides/182-how-to-connect-to-access-server-with-linux-clients.html).

To summarize, we will be building the below components:

- VPC
- Internet Gateway for public subnet
- Public subnet for routing instances
- Private subnet for application resources
- Routing table for public subnet
- Routing table for private subnet
- NAT/VPN server to route outbound traffic from your instances in private network and provide your workstation secure access to private network resources.
connect instances private network and provide you access 
- App servers running nginx in private subnet
- Load balancers in the public subnet to manage and route web traffic to app servers

The network components can be built and managed using the native AWS web console but it makes your infrastrcuture operatianally vurnerable to changes and surprises. Automating the building, changing, and versioning your infrastructure safely and effeciently increases your operational readiness exponentially. It allows you move at an extremly velocity and take risks as you grow your infrstrature while making you almost. Automation lays the foundation to easily provision your infrastrure across many types of clouds to manage heterogeneous information systems.

[Terraform](https://www.terraform.io) is automation tool for the cloud. It provides powerful primitives to elegantly define your infrastructure as code. It extremely easy to build and make updates your infrastructure that can version controlled and collaborative. Terraform uses user defined configuration files with a simple yet powerful syntax to describe infrastructure components and generates an execution plan describing what it will do to reach the desired state. You can then choose to execute (or modify) the pln to build or removed desired infrasture components.

Pre-requisites
--------------

- AWS access and secret keys to an active AWS account
- A workstation with internet connection

Please note, you will be creating real instances that cost money. I did my best to keep the utilization foot print to the lowest possible configuration, and I estimate less than hour to complete all the steps in this guide.

We will also be destroying all the infrastructure components created during this tutorial to demonstrate the disposable nature of infstrasture-of-code.

Settting up your workstation
-----------------------------

You can install terraform using homebrew on a Mac using ```brew install terraform```. Alternative, find the [appropriate package](https://www.terraform.io/downloads.html) for your system and download it. Terraform is packaged as a zip archive. After downloading Terraform, unzip the contents of the zip archive to directory that is in your `PATH`, ideally under `/usr/local/bin`. You can verify terraform is properly installed by running `terraform`, it should return something like:

```sh
usage: terraform [--version] [--help] <command> [<args>]

Available commands are:
    apply      Builds or changes infrastructure
    destroy    Destroy Terraform-managed infrastructure
    get        Download and install modules for the configuration
    graph      Create a visual graph of Terraform resources
    init       Initializes Terraform configuration from a module
    output     Read an output from a state file
    plan       Generate and show an execution plan
    pull       Refreshes the local state copy from the remote server
    push       Uploads the the local state to the remote server
    refresh    Update local state file against real resources
    remote     Configures remote state management
    show       Inspect Terraform state or plan
    version    Prints the Terraform version
```

Setting your project directory
------------------------------

Create a directory to host your project files. For our example, we will use `$HOME/infrastructure`, with the below structure:

```sh
.
├── cloud-config
├── bin
└── ssh
```

```sh
$ mkdir -p $HOME/infrastructure/cloud-config $HOME/infrastructure/ssh $HOME/infrastructure/ssh
$ cd $HOME/infrastructure
```

Defining variables for your infrastructure
------------------------------------------

Configurations can be defined in any file with '.tf' extention using terraform syntax or json syntax. Its a good practice to start with a `variables.tf` that defines all variables that can be easily changed to tune your infrastructure. Create a file called `variables.tf` with the below contents:

```
variable "access_key" { 
  description = "AWS access key"
}

variable "secret_key" { 
  description = "AWS secert access key"
}

variable "region"     { 
  description = "AWS region to host your network"
  default     = "us-west-1" 
}

variable "vpc_cidr" {
  description = "CIDR for VPC"
  default     = "10.128.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  default     = "10.128.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for private subnet"
  default     = "10.128.1.0/24"
}

/* Ubuntu 14.04 amis by region */
variable "amis" {
  description = "Base AMI to launch the instances with"
  default = {
    us-west-1 = "ami-049d8641" 
    us-east-1 = "ami-a6b8e7ce"
  }
}
```

The `variable` block defines a single input variable your configuration will require to provision your infrastructure, `description` parameter is used to describe what the variable is used for and `default` parameter gives it a default value, our example requires that you provide ```access_key``` and ```secret_key``` variables and optionally provide ```region```, region will default to `us-west-1` when not provided.

Variables can also have multiple default values with keys to access them, such variables are called maps. Values in maps can be accessed using interoplation systax which will be covered in the next section of the guide

Creating your first terraform resource - VPC
---------------------------------------------

Create a `aws-vpc.tf` file in the current directory with the below configuration:

```
/* Setup our aws provider */
provider "aws" {
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
  region      = "${var.region}"
}

/* Define our vpc */
resource "aws_vpc" "default" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags { 
    Name = "airpair-example" 
  }
}
```

The `provider` block defines what provider to build the infructure for, Terraform has support for various other providers like Google Compute Cloud, DigitalOcean, Heroku etc. You can see a list of supported providers on the [providers page](https://www.terraform.io/docs/providers/index.html)

`resource` block defines the resource being created. The above example creates a VPC with a CIDR block of `10.128.0.0/16` and attaches a Name tag `airpair-example`, you can read more about various other parameters that can be defined for ```aws_vpc``` on the [aws_vpc resource documentation page](https://www.terraform.io/docs/providers/aws/r/vpc.html)

Provisioning your VPC
---------------------

Running `terraform apply` will create the VPC by prompting you to to input AWS access key and secret key, the output should look like look like:

```sh
$ terraform apply
var.access_key
  AWS access key

  Enter a value: foo

...

var.secret_key
  AWS secert access key

  Enter a value: bar

...

aws_vpc.default: Creating...
  cidr_block:                "" => "10.128.0.0/16"
  default_network_acl_id:    "" => "<computed>"
  default_security_group_id: "" => "<computed>"
  enable_dns_hostnames:      "" => "1"
  enable_dns_support:        "" => "0"
  main_route_table_id:       "" => "<computed>"
  tags.#:                    "" => "1"
  tags.Name:                 "" => "airpair-example"
aws_vpc.default: Creation complete

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate
```

You can verify the VPC has been created by visiting the [VPC page on aws console](https://console.aws.amazon.com/vpc/home?region=us-west-1#vpcs). The above command will save the state of your infrastructure to `terraform.tfstate` file, this file will be updated each time you run `terraform apply`, you can inspect the current state of your infrastructure by running `terraform show`

Variables can also be entered using command arguments by specifying `-var 'var=VALUE'`, for example ```terraform plan -var 'access_key=foo' -var 'secret_key=bar'```

`terraform apply` will not however save your input values (access and secret keys) and you'll be required to provide them for each update, to avoid this create a `terraform.tfvars` variables file with your access and secret keys that looks like, the below (replace foo and bar with your values):

```
access_key = "foo"
secret_key = "bar"
```


Updating your infrastructure
----------------------------

Lets now add a public subnet with a ip range of 10.128.0.0/24 and attach a internet gateway, append below configuration to our `main.tf` file:

```
/* Internet gateway */
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

/* Public subnet */
resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.128.0.0/24"
  availability_zone = "us-west-1a"
  map_public_ip_on_launch = true
  tags {
    Name = "public"
  }
}

/* Routing table for public subnet */
resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.default.id}"
  }
}

/* Associate the routing table to public subnet */
resource "aws_route_table_association" "public" {
  subnet_id = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}
```

Resources can be referenced using [interpolation syntax](https://www.terraform.io/docs/configuration/interpolation.html) by wrapping them with `${}`. In the `aws_internet_gateway` resource block, specifying `${aws_vpc.default.id}` for `vpc_id` will create gateway under the `default` vpc.

Anything under ```/* .. */``` will be considered as comments.

Running `terraform plan` will generate an execution plan for you to verify before creating the actual resources, it is recommended that you always inspect the plan before running the `apply` command. The output of `terraform plan` should look something like the below:

```sh
$ terraform plan

Refreshing Terraform state prior to plan...

aws_vpc.default: Refreshing state... (ID: vpc-30965455)

The Terraform execution plan has been generated and is shown below.
Resources are shown in alphabetical order for quick scanning. Green resources
will be created (or destroyed and then created if an existing resource
exists), yellow resources are being changed in-place, and red resources
will be destroyed.

Note: You didn't specify an "-out" parameter to save this plan, so when
"apply" is called, Terraform can't guarantee this is what will execute.

+ aws_internet_gateway.default
    vpc_id: "" => "vpc-30965455"

+ aws_route_table.public
    route.#:                       "" => "1"
    route.~1235774185.cidr_block:  "" => "0.0.0.0/0"
    route.~1235774185.gateway_id:  "" => "${aws_internet_gateway.default.id}"
    route.~1235774185.instance_id: "" => ""
    vpc_id:                        "" => "vpc-30965455"

+ aws_route_table_association.public
    route_table_id: "" => "${aws_route_table.public.id}"
    subnet_id:      "" => "${aws_subnet.public.id}"

+ aws_subnet.public
    availability_zone:       "" => "us-west-1a"
    cidr_block:              "" => "10.128.0.0/24"
    map_public_ip_on_launch: "" => "1"
    tags.#:                  "" => "1"
    tags.Name:               "" => "public"
    vpc_id:                  "" => "vpc-30965455"
```

The `+` before `aws_internet_gateway.default` indicates that a new resource will be created. After reviewing your plan, run `terraform apply` to create your resources, you can verify by running `terraform show` or by visiting the aws console.  

*The vpc_id will different in your actual output from the above example output*

Create security groups
----------------------

We will creating 3 security groups:

- default: default security group that allows inbound and outbound traffic from all instances in the VPC
- nat: security group for nat instances that allows SSH traffic from internet
- web: security group that allows web traffic from the internet

To keep our `main.tf` at a managable size, lets create our security groups in a `sgroups.tf` file with the below configuration. Terraform will load all files with a `.tf` extention.

```
/* default security group */
resource "aws_security_group" "default" {
  name = "default-vpc"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id = "${aws_vpc.default.id}"
  
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
  }
  
  tags { Name = "default-vpc" }
}


/* Security group for the nat server */
resource "aws_security_group" "nat" {
  name = "nat"
  description = "Security group for nat instances that allows SSH and VPN traffic from internet"
  vpc_id = "${aws_vpc.default.id}"
  
  ingress {
    from_port = 22
    to_port  = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 1194
    to_port  = 1194
    protocol = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags { Name = "nat" }
}

/* Security group for the web */
resource "aws_security_group" "web" {
  name = "web"
  description = "Security group for web that allows web traffic from internet"
  vpc_id = "${aws_vpc.default.id}"
  
  ingress {
    from_port = 80
    to_port  = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 443
    to_port  = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags { Name = "web" }
}
```

Run `terraform plan`, review your changes and run `terraform apply`. You should see a message:

```sh
...

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

...
```

Create SSH Key Pair
-------------------

We will need a default ssh key to be bootstraped on the newly created instances to be able to login, generate a new key by running:

```sh
$ mkdir -p ssh # make sure the ssh directory exists
$ sh-keygen -t rsa -C "insecure-deployer" -P '' -f ssh/insecure-deployer
```

The above command will create a public-private key pair under ssh, this is an insecure key and should be replaced after the instance is boostraped.

Register the newly generated SSH key pair by adding the below config to your `main.tf` and run `terraform plan` and `terraform apply`.

```
resource "aws_key_pair" "deployer" {
  key_name = "deployer-key"
  public_key = "${file(\"ssh/insecure-deployer.pub\")}"
}
```

Terraform interpolation syntax allows reading data from files. Variables in this file are not interpolated. The contents of the file are read as-is.

Create NAT Instance
-------------------

NAT instances reside in the public subnet and in order to route traffic, they need to have 'source destination check' disabled. Also, they belong to the `default` secruity group to allow traffic from instances in that group and `nat` security group to allow SSH and VPN traffic from the internet. Create a file `nat.tf` with the below config:

```
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
```

Create private subnet and configure routing
-------------------------------------------
Create a private subnet with a CIDR range of 10.128.1.0/24 and configure the routing table to route all traffic via the nat. Append 'main.tf' with the below config:

```
/* Private subnet */
resource "aws_subnet" "private" {
  vpc_id            = "${aws_vpc.default.id}"
  cidr_block        = "10.128.1.0/24"
  availability_zone = "us-west-1a"
  map_public_ip_on_launch = false
  tags { 
    Name = "private" 
  }
}

/* Routing table for private subnet */
resource "aws_route_table" "private" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    instance_id = "${aws_instance.nat.id}"
  }
}

/* Associate the routing table to public subnet */
resource "aws_route_table_association" "private" {
  subnet_id = "${aws_subnet.private.id}"
  route_table_id = "${aws_route_table.private.id}"
}
```

Run ```terraform plan``` and ```terraform apply```

Adding app instances and a load balancer
----------------------------------------

Lets add two app servers running nginx containers in the private subnet and configure a load balancer in the public subnet. 

The app servers are not accessible directly from the internet and can be accessed via the VPN. Since we haven't configured our VPN yet to access the instances, we will provision the instances using by bootrapping `cloud-init` yaml file via the ```user_data``` parameter.

`cloud-init` is a defacto multi-distribution package that handles early initialization of a cloud instance. You can see various examples [in the documentation](http://cloudinit.readthedocs.org/en/latest/topics/examples.html)

Create `app.yml` cloud config file under `cloud-config` directory with the below config:

```yaml
#cloud-config
# Cloud config for application servers 

runcmd:
  # Install docker
  - curl -sSL https://get.docker.com/ubuntu/ | sudo sh
  # Run nginx
  - docker run -d -p 80:80 dockerfile/nginx

```

Create `app.tf` file with the below configuration:

```
/* App servers */
resource "aws_instance" "app" {
  count = 2
  ami = "ami-049d8641"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.private.id}"
  security_groups = ["${aws_security_group.default.id}"]
  key_name = "${aws_key_pair.deployer.key_name}"
  source_dest_check = false
  user_data = "${file(\"cloud-config/app.yml\")}"
  tags = { 
    Name = "airpair-example-app-${count.index}"
  }
}

/* Load balancer */
resource "aws_elb" "app" {
  name = "airpair-example-elb"
  subnets = ["${aws_subnet.public.id}"]
  security_groups = ["${aws_security_group.default.id}", "${aws_security_group.web.id}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  instances = ["${aws_instance.app.*.id}"]
}

```

`count` parameter indicates the number of identical resources to create and `${count.index}` interpolation in the name tag provides the current index.

You read more about using count in resources at [terraform variable documentation](https://www.terraform.io/docs/configuration/resources.html#using-variables-with-count)

Run ```terraform plan``` and ```terraform apply```

Configure OpenVPN server and generate client config
---------------------------------------------------

1. Initialize PKI

  ```
  ssh -t -i ssh/insecure-deployer \
  ubuntu@$(terraform output nat.ip) \
  sudo docker run --volumes-from ovpn-data --rm -it gosuri/openvpn ovpn_initpki
  ```

  The above command will prompt you for a passphrase for the root certificate, choose a strong passphrase and store is some where you'll rememeber. This passphrase is required every time you genenerate a new client configuration.

2. Start the VPN server

  ```
  ssh -t -i ssh/insecure-deployer \
  ubuntu@$(terraform output nat.ip) \
  sudo docker run --volumes-from ovpn-data -d -p 1194:1194/udp --cap-add=NET_ADMIN gosuri/openvpn
  ```

3. Generate client certificate

  ```
  ssh -t -i ssh/insecure-deployer \
  ubuntu@$(terraform output nat.ip) \
  sudo docker run --volumes-from ovpn-data --rm -it gosuri/openvpn easyrsa build-client-full $USER nopass
  ```

4. Download VPN config

  ```
  ssh -t -i ssh/insecure-deployer \
  ubuntu@$(terraform output nat.ip) \
  sudo docker run --volumes-from ovpn-data --rm gosuri/openvpn ovpn_getclient $USER > $USER.ovpn
  ```

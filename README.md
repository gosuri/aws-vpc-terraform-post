Building and automating a secure infrastructure on AWS using Terraform and Chef
===============================================================================

Architecture
------------

We will essentially be building a Virtual Private Cloud (VPC) on AWS which comprises of a public and a private subnet. The private subnet will comprise of application and database instances along with any other resource(s) required to serve your application. 

The instances in the public subnet can receive inbound traffic from the internet, whereas instances in the private can't. Instances in the public subnet can also send outbound traffic to the internet, whereas instances in the private network can't, thereby making the private subnet an ideal place for application and database servers.

Instances in the private subnet rely on a Network Address Translation (NAT) server running in the public subnet to connect to the internet, thereby making the NAT server a router. 

The NAT server will also act as a VPN server running OpenVPN, a full-featured SSL VPN which implements OSI layer 3 secure network extension using the industry standard SSL/TLS protocol over a UDP encapsulated network.

Connection to our VPN server will be established using any OpenVPN clients [Tunnelblick for Mac](https://code.google.com/p/tunnelblick/)

To summary, we will be building the below components:

- VPC
- Public subnet
- Private subnet
- Internet Gateway for public subnet
- Routing table for public subnet
- Routing table for private subnet
- NAT/VPN server

The VPC and instances can be built using the AWS web console but using [Terraform](https://www.terraform.io) makes it extremely easy to build and make updates your infrastructure that can version controlled and collaborative. Terraform uses configuration files to describe infrastructure components and generates an execution plan describing what it will do to reach the desired state, and then executes it to build the described infrastructure.

Setup
-----

## Terraform

To install Terraform, find the [appropriate package](https://www.terraform.io/downloads.html) for your system and download it. Terraform is packaged as a zip archive. After downloading Terraform, unzip the contents of the zip archive to directory that is in your `PATH`, ideally under `/usr/local/bin`. You can verify terraform is properly installed by running `terraform`, it should return something like:

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

## Project Template

Create a directory to host your project files. For our example, we will use `$HOME/infrastructure`

```sh
$ mkdir $HOME/infrastructure
$ cd $HOME/infrastructure
```

Your first terraform configuration file
---------------------------------------

Create a file under our project directory called `main.tf` with the below contents

```
variable "access_key" {
  description = "AWS access key"
}

variable "secret_key" {
  description = "AWS secret access key"
}

variable "region"     {
  description = "AWS region"
  default = "us-west-1"
}

provider "aws" {
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
  region      = "${var.region}"
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.128.0/16"
  tags {
    Name = "airpair-example"
  }
}
```

The `variable` block defines a single input variable your configuration will require to provision, `description` parameter is used to describe what the variable is used for and `default` parameter gives it a default value, our example requires that you provide ```access_key``` and ```secret_key``` variables and optionally provide ```region```, region will default to `us-west-1` when not provided.

The `provider` block defines what provider to build the infructure for, Terraform has support for various other providers like Google Compute Cloud, DigitalOcean, Heroku etc. You can see a list of supported providers on the [providers page](https://www.terraform.io/docs/providers/index.html)

`resource` block defines the resource being created. The above example creates a VPC with a CIDR block of `10.0.128.0/16` and attaches a Name tag `airpair-example`, you can read more about various other parameters that can be defined for ```aws_vpc``` on the [aws_vpc resource documentation page](https://www.terraform.io/docs/providers/aws/r/vpc.html)


Provisioning your VPC
---------------------

Running `terraform apply` will prompt you for inputs and create the VPC appropriate values for AWS access key and secret key are entered

```sh
$ terraform apply
var.access_key
  AWS access key

  Enter a value: foo

var.region
  AWS region

  Default: us-west-1
  Enter a value:

var.secret_key
  AWS secert access key

  Enter a value: bar

aws_vpc.default: Creating...
  cidr_block:                "" => "10.0.128.0/16"
  default_network_acl_id:    "" => "<computed>"
  default_security_group_id: "" => "<computed>"
  enable_dns_hostnames:      "" => "0"
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

You can verify the VPC has been created by visiting the [VPC page on aws console](https://console.aws.amazon.com/vpc/home?region=us-west-1#vpcs). The above command will save the state of your infrastructure to `terraform.tfstate` file, this file will be updated each time you run `terraform apply`, you can inspect this file to understand how terraform manages your state.

Variables can also be entered using command arguments by specifying `-var 'var=VALUE'`, for example ``terraform plan -var 'access_key=foo' -var 'secret_key=bar'```

`terraform apply` will not however save your input values (access and secret keys) and you'll be required to provide them for each update, to avoid this create a `terraform.tfvars` variables file with your access and secret keys that looks like, the below (replace foo and bar with your values):

```
access_key = "foo"
secret_key = "bar"
```

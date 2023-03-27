aws-cfn-vdi
===========

AWS CloudFormation stacks of VDI

[![Lint](https://github.com/dceoy/aws-cfn-vdi/actions/workflows/lint.yml/badge.svg)](https://github.com/dceoy/aws-cfn-vdi/actions/workflows/lint.yml)

Installation
------------

1.  Check out the repository.

    ```sh
    $ git clone --recurse-submodules git@github.com:dceoy/aws-cfn-vdi.git
    $ cd aws-cfn-vdi
    ```

2.  Install [Rain](https://github.com/aws-cloudformation/rain) and set `~/.aws/config` and `~/.aws/credentials`.

3.  Deploy stacks for VPC.

    ```sh
    $ rain deploy \
        --params ProjectName=slhpc-dev \
        aws-cfn-vpc-for-slc/vpc-private-subnets-with-endpoints.cfn.yml \
        slhpc-dev-vpc-private
    $ rain deploy \
        --params ProjectName=slhpc-dev,VpcStackName=slhpc-dev-vpc-private \
        aws-cfn-vpc-for-slc/vpc-public-subnets-with-nat-gateway-per-az.cfn.yml \
        slhpc-dev-vpc-public
    ```

4.  Deploy WorkSpaces stacks.

    ```sh
    $ rain deploy \
        workspace.cfn.yml \
        workspace
    ```

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

2.  Install [Rain](https://github.com/aws-cloudformation/rain) and [AWS CLI](https://aws.amazon.com/cli/), and set `~/.aws/config` and `~/.aws/credentials`.

3.  Deploy stacks for VPC.

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev \
        aws-cfn-vpc-for-slc/vpc-private-subnets-with-gateway-endpoints.cfn.yml \
        vdi-dev-vpc-private-subnets-with-gateway-endpoints
    $ rain deploy \
        --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints \
        aws-cfn-vpc-for-slc/vpc-public-subnets-with-nat-gateway-in-1az.cfn.yml \
        vdi-dev-vpc-public-subnets-with-nat-gateway-in-1az
    ```

4.  Deploy S3 and IAM stacks for AppStream 2.0.

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev \
        s3-bucket-for-appstream.cfn.yml vdi-dev-s3-bucket-for-appstream
    $ rain deploy \
        --params ProjectName=vdi-dev \
        iam-role-for-appstream.cfn.yml vdi-dev-iam-role-for-appstream
    ```

5.  Deploy stacks of AppStream 2.0.

    - Linux image builder

      ```sh
      $ rain deploy \
          --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-role-for-appstream \
          appstream-image-builder.cfn.yml vdi-dev-appstream-linux-image-builder
      ```

    - Linux elastic fleet and stack

      ```sh
      $ rain deploy \
          --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-role-for-appstream \
          appstream-elatic-fleet-stack.cfn.yml vdi-dev-appstream-elatic-fleet-stack
      ```

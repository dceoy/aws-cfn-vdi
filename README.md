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

3.  Deploy VPC stacks.

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
        iam-roles-for-appstream.cfn.yml vdi-dev-iam-roles-for-appstream
    ```

5.  Deploy EFS stacks. (optional)

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints \
        aws-cfn-nfs/efs-with-access-point.cfn.yml vdi-dev-efs-with-access-point
    ```

6.  Deploy stacks of an AppStream 2.0 image builder.

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-roles-for-appstream \
        appstream-image-builder.cfn.yml vdi-dev-appstream-linux-image-builder
    ```

7.  Execute the following script and create an AppStream 2.0 image in an AppStream 2.0 image builder instance.

    ```sh
    $ curl -SL https://raw.githubusercontent.com/dceoy/aws-cfn-vdi/main/scripts/create_al2_image.sh | bash
    ```

8.  Deploy stacks of an AppStream 2.0 on-demand fleet.

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev,ImageName=al2-with-docker,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-roles-for-appstream \
        appstream-ondemand-fleet-and-stack.cfn.yml vdi-dev-appstream-ondemand-fleet-and-stack
    $ aws appstream start-fleet \
        --name vdi-dev-appstream-ondemand-fleet-al2-with-docker
    ```

9.  Deploy stacks for AppStream 2.0 auto scaling. (optional)

    ```sh
    $ rain deploy \
        --params AppStreamStackName=vdi-dev-appstream-ondemand-fleet-and-stack,IamStackName=vdi-dev-iam-roles-for-appstream \
        appstream-auto-scaling.cfn.yml vdi-dev-appstream-auto-scaling
    ```

10. Associate a new user with a stack.

    ```sh
    $ aws appstream create-user \
        --user-name foo.bar@example.com \
        --first-name foo \
        --last-name bar \
        --authentication-type USERPOOL
    $ rain deploy \
        --params UserName=foo.bar@example.com,AppStreamStackName=vdi-dev-appstream-ondemand-fleet-and-stack \
        appstream-user-association.cfn.yml vdi-dev-appstream-user-association
    ```

    Delete a user.

    ```sh
    $ rain rm -y vdi-dev-appstream-user-association
    $ aws appstream delete-user \
        --user-name foo.bar@example.com \
        --authentication-type USERPOOL
    ```

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

4.  Deploy IAM and S3 stacks for AppStream 2.0.

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev \
        iam-roles-for-appstream.cfn.yml vdi-dev-iam-roles-for-appstream
    $ rain deploy \
        --params ProjectName=vdi-dev \
        s3-bucket-for-appstream.cfn.yml vdi-dev-s3-bucket-for-appstream
    ```

5.  Deploy EFS stacks. (optional)

    ```sh
    $ rain deploy \
        --params ProjectName=vdi-dev,VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints \
        aws-cfn-nfs/efs-with-access-point.cfn.yml vdi-dev-efs-with-access-point
    ```

6.  Deploy stacks of an AppStream 2.0 image builder.

    ```sh
    $ base_image=$(aws appstream describe-images --query 'Images[*].Name' | grep -oe 'AppStream-AmazonLinux[^"]\+' | tail -1)
    $ rain deploy \
        --params ProjectName=vdi-dev,ImageName="${base_image}",VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-roles-for-appstream \
        appstream-image-builder.cfn.yml "vdi-dev-appstream-image-builder-${base_image}"
    ```

7.  Execute the following script and create an AppStream 2.0 image in an AppStream 2.0 image builder instance.

    ```sh
    $ curl -SLO https://raw.githubusercontent.com/dceoy/aws-cfn-vdi/main/create_as2_image.sh
    $ bash create_as2_image.sh
    ```

8.  Deploy stacks of an AppStream 2.0 on-demand fleet.

    ```sh
    $ as2_image=$(aws appstream describe-images --query 'Images[*].Name' | grep -oe "vdi-dev-as2-[^\"]\+" | tail -1)
    $ rain deploy \
        --params ProjectName=vdi-dev,ImageName="${as2_image}",VpcStackName=vdi-dev-vpc-private-subnets-with-gateway-endpoints,IamStackName=vdi-dev-iam-roles-for-appstream \
        appstream-ondemand-fleet-and-stack.cfn.yml vdi-dev-appstream-ondemand-fleet-and-stack
    $ aws cloudformation describe-stacks \
        --query 'Stacks[0].Outputs[?OutputKey==`AppStreamFleet`].OutputValue' \
        --output text \
        --stack-name vdi-dev-appstream-ondemand-fleet-and-stack \
        | xargs -t -L1 aws appstream start-fleet --name
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
    $ aws appstream batch-associate-user-stack \
        --user-stack-associations \
        '[{"StackName": "vdi-dev-as2-odfs-stream-standard-small", "UserName": "foo.bar@example.com", "AuthenticationType": "USERPOOL", "SendEmailNotification": true}]'
    ```

    Delete a user.

    ```sh
    $ aws appstream batch-disassociate-user-stack \
        --user-stack-associations \
        '[{"StackName": "vdi-dev-as2-odfs-stream-standard-small", "UserName": "foo.bar@example.com", "AuthenticationType": "USERPOOL", "SendEmailNotification": true}]'
    $ aws appstream delete-user \
        --user-name foo.bar@example.com \
        --authentication-type USERPOOL
    ```

11. Creates a lifecycle configuration for S3 buckets created by AppStream 2.0.

    ```sh
    $ aws s3api put-bucket-versioning \
        --versioning-configuration Status=Enabled \
        --bucket <bucket_name>
    $ aws s3api put-bucket-lifecycle-configuration \
        --lifecycle-configuration file://s3-lifecycle-configuration.json \
        --bucket <bucket_name>
    ```

    Get the lifecycle configurations of the S3 buckets.

    ```sh
    $ aws s3 ls \
        | grep -oe 'appstream[a-z0-9\-]\+$' \
        | xargs -t -L1 aws s3api get-bucket-lifecycle-configuration --bucket
    ```

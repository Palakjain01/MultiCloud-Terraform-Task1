# MultiCloud-Terraform-Application

Create/launch an Application using Terraform

1. Create a key and security group which allow port number 80.

2. Launch an EC2 instance.

3. In this EC2 instance use the key and security group created in step 1.

4. Launch one EBS Volume and mount that volume into /var/www/html.

5. Developer have uploded the code into github repo including some images as well.

6. Copy the github repo code into /var/www/html

7. Create S3 bucket, and copy/deploy the images into the s3 bucket with permission to public readable.

8 Create a Cloudfront using s3 bucket(which contains images) and use the Cloudfront URL to  update in code in /var/www/html

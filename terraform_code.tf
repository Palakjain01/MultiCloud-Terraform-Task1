provider "aws" {
  region ="ap-south-1"
  profile = "infinity"

}


			  // LAUNCHING A KEY-PAIR

resource "tls_private_key" "t1_key" {             //key generation 
  algorithm = "RSA"
}

resource "local_file" "t1_privatekey" {
    content     = tls_private_key.t1_key.private_key_pem
    filename = "task1_privatekey.pem"
    file_permission = 0400                             
}

resource "aws_key_pair" "t1_key"{                 //terraform ---> aws
	key_name= "task1_privatekey"
	public_key = tls_private_key.t1_key.public_key_openssh
}


                       //LAUNCHING A SECURITY GROUP

resource "aws_security_group" "t1_sg" {
  depends_on = [tls_private_key.t1_key,]  
  name        = "task1_sg" 
  description = "Allow SSH and HTTP"
  vpc_id      = "vpc-1ee5f876"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task1_sg" 
  }
}


				// LAUNCHING AN AWS INSTANCE

resource "aws_instance" "t1_instance"{
 
    depends_on = [aws_security_group.t1_sg,]
  	ami           = "ami-0447a12f28fddb066"
  	instance_type = "t2.micro"
  	key_name  = 	aws_key_pair.t1_key.key_name  
  	security_groups  = ["task1_sg" ]


	connection {
    		type     = "ssh"
    		user     = "ec2-user"
    		private_key = tls_private_key.t1_key.private_key_pem	
   	 	host     = aws_instance.t1_instance.public_ip
  		}

	provisioner "remote-exec" {
    		inline = [
		"sudo yum install httpd php git -y",
		"sudo systemctl restart httpd",
		"sudo systemctl enable httpd"
    			]
  		}

  	tags = {
    		Name = "task1_os1"
  		}
	}


                         //LAUNCHING AN EBS VOLUME		

resource "aws_ebs_volume" "t1_ebs1" {
  depends_on = [aws_instance.t1_instance,]
  availability_zone = aws_instance.t1_instance.availability_zone
  size              = 1

  tags = {
	Name = "task1_ebs"
 	 }
}


			
                    //ATTACHING CREATED EBS VOLUME TO INSTANCE

resource "aws_volume_attachment" "t1_ebs_att" {
  depends_on = [aws_ebs_volume.t1_ebs1,]
  device_name = "/dev/sdd"
  volume_id   = aws_ebs_volume.t1_ebs1.id
  instance_id = aws_instance.t1_instance.id
  force_detach=true

}

                   //MOUNTING EBS VOLUME TO INSTANCE
 
resource "null_resource" "nullRemote3" {
  depends_on = [aws_volume_attachment.t1_ebs_att,]
  

  connection {
    type   	  = "ssh"
    user   	  = "ec2-user"
    private_key   = tls_private_key.t1_key.private_key_pem
    host          = aws_instance.t1_instance.public_ip
    }

  provisioner "remote-exec" {
    inline = [
	"sudo mkfs.ext4 /dev/xvdd",
	"sudo mount /dev/xvdd  /var/www/html",
	"sudo rm -rf /var/www/html/*",
	"sudo git clone https://github.com/Palakjain01/MultiCloud-Terraform-Task1.git  /var/www/html"
    ]
  }
}


                         
resource "null_resource" "nullLocal1" {        // Saving the Public IP of instance for future usage      
      depends_on = [null_resource.nullRemote3,]
      provisioner "local-exec" {
           command = "echo ${aws_instance.t1_instance.public_ip} > public_ip.txt"
  }
}


			// CREATING AN S3 BUCKET

resource "aws_s3_bucket" "t1bucket" {
    depends_on = [null_resource.nullRemote3 ,]
  	bucket = "infinitytask1bucket"
  	acl    = "public-read"
  	tags = {
    		Name        = "task1_bucket"
  		}
	}


			// S3 OBJECT

resource "aws_s3_bucket_object" "file_upload" {

    depends_on = [aws_s3_bucket.t1bucket,]	
  	content_type="image/jpeg"             
  	bucket = "infinitytask1bucket"
  	key    = "multicloud.png"           
  	source = "C:/Users/hp/Desktop/HybridCloud/tera/multicloud.png"
  	etag   = filemd5("C:/Users/hp/Desktop/HybridCloud/tera/multicloud.png")
  	acl    = "public-read"            
	}

	
 			
			//LOCAL 	

locals {                

	s3_origin = "infinityS3"
}

			// CLOUD FRONT 

resource "aws_cloudfront_distribution" "t1_cd" {

   depends_on = [aws_s3_bucket.t1bucket,]
   	origin {
   		domain_name = aws_s3_bucket.t1bucket.bucket_regional_domain_name
   		origin_id   = local.s3_origin
  		}
  	enabled             = true

 	default_cache_behavior {
    		allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    		cached_methods   = ["GET", "HEAD"]
    		target_origin_id = local.s3_origin
    		forwarded_values {
      			query_string = true             

		      	cookies {
        			forward = "none"
     				}
    				}

    	viewer_protocol_policy = "allow-all"
    	min_ttl                = 0
    	default_ttl            = 3600
    	max_ttl                = 86400
  }

  
  	restrictions {
    	geo_restriction {
      	restriction_type = "none"
    }
  }

  	viewer_certificate {
    		cloudfront_default_certificate = true
  			}
}

			// SETTING CLOUDFRONT URL IN THE WEBPAGE

resource "null_resource" "nullRemote4" {
   depends_on = [aws_cloudfront_distribution.t1_cd,]
	connection {
    	type   	  = "ssh"
    	user   	  = "ec2-user"
    	private_key   = tls_private_key.t1_key.private_key_pem
    	host          = aws_instance.t1_instance.public_ip
    	}

	provisioner "remote-exec" {
		inline = [
			"sudo sed -i 's@path@https://${aws_cloudfront_distribution.t1_cd.domain_name}/${aws_s3_bucket_object.file_upload.key}@g' /var/www/html/index.php"
		]
	}
}


resource "null_resource" "nullLocal2" {    // Saving the Cloudfront URL
      depends_on = [aws_cloudfront_distribution.t1_cd,]
	      provisioner "local-exec" {
        	   command = "echo ${aws_cloudfront_distribution.t1_cd.domain_name} > cf_URL.txt"
  }
}

			//DISPLAYING THE PUBLIC IP OF AWS INSTANCE
output "instanceIP" {
	depends_on = [null_resource.nullLocal2,]
	value=aws_instance.t1_instance.public_ip
}



















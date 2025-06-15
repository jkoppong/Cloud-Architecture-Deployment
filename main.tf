terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "eu-west-2"
}

resource "aws_s3_bucket" "website_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_object" "home_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "home.html"
  source = "website/home.html"
  etag = filemd5("website/home.html")
  content_type = "text/html"
}

resource "aws_s3_object" "poetry_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "poetry.html"
  source = "website/poetry.html"
  etag = filemd5("website/poetry.html")
  content_type = "text/html"
}

resource "aws_s3_object" "shows_html" {
  bucket = aws_s3_bucket.website_bucket.id
  key = "shows.html"
  source = "website/shows.html"
  etag = filemd5("website/shows.html")
  content_type = "text/html"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Origin Access Identity for static website"
}

resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_id = var.bucket_name

    s3_origin_config {
     origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled = true
  is_ipv6_enabled = true
  default_root_object = var.website_home_document

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    target_origin_id = var.bucket_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

tags = {
   Name = "Cloudfront Distribution" 
   Environment = "Dev"
}
}

resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action = "s3:GetObject"
            Effect = "Allow"
            Resource = "${aws_s3_bucket.website_bucket.arn}/*"
            Principal = {
                CanonicalUser = aws_cloudfront_origin_access_identity.origin_access_identity.s3_canonical_user_id
            }
        }
    ]
  })
}


resource "aws_wafv2_web_acl" "waf_web_acl" {
  name = "my-waf-acl"
  scope = "REGIONAL"
  default_action {
    allow {
    }
  }
  visibility_config {
    sampled_requests_enabled = true
    cloudwatch_metrics_enabled = true
    metric_name = "waf_metrics"
  }
}

resource "aws_wafv2_web_acl_logging_configuration" "website_log_configuration" {
  resource_arn = aws_wafv2_web_acl.waf_web_acl.arn
  log_destination_configs = [
    aws_cloudwatch_log_group.waf_log_group.arn
  ]
}

resource "aws_cloudwatch_log_group" "waf_log_group" {
  name                  = "aws-waf-logs-waf_log_group"
  retention_in_days     = 30
}
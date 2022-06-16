resource "aws_ecr_repository" "pythonapp-repository" {
  name                 = var.ecr_name
  image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecr_repository_policy" "pythonapp-repository-policy" {
  repository = aws_ecr_repository.pythonapp-repository.name
  policy     = <<EOF
  {
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "adds full ecr access to the python repository",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetLifecyclePolicy",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]
      }
    ]
  }
  EOF
}
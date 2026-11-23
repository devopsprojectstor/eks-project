# Lets the app repo's CI role sign images with the KMS key created in bootstrap/.
# The permission is on the role (not in the key policy), so it is recreated
# together with the role on every cluster rebuild.

data "aws_kms_alias" "image_signing" {
  name = "alias/two-tier-image-signing"
}

resource "aws_iam_role_policy" "app_deploy_signing" {
  name = "image-signing"
  role = aws_iam_role.app_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Sign", "kms:GetPublicKey", "kms:DescribeKey"]
      Resource = data.aws_kms_alias.image_signing.target_key_arn
    }]
  })
}

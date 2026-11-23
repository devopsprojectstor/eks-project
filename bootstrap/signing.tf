# Image signing key for cosign. Lives in bootstrap because it must NEVER be
# destroyed with the cluster: deleting it makes every existing signature unverifiable.
#
# Reuses data.aws_caller_identity.current from main.tf.

variable "signer_role_name" {
  description = "The only IAM role allowed to sign images (the app repo's CI role, created in eks/)"
  type        = string
  default     = "two-tier-eks-app-deploy"
}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  signer_role_arn = "arn:aws:iam::${local.account_id}:role/${var.signer_role_name}"
}

resource "aws_kms_key" "image_signing" {
  description              = "Signs container images for two-tier (cosign)"
  key_usage                = "SIGN_VERIFY"
  customer_master_key_spec = "ECC_NIST_P256" # the key type cosign expects
  deletion_window_in_days  = 30              # maximum: time to notice an accidental deletion

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Standard: let IAM policies in this account control access to the key.
        Sid       = "EnableIAMPolicies"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${local.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # Guard rail: nobody except the CI signing role can sign, not even admins.
        # Matches the role's ARN as a string, so it keeps working when the role is
        # deleted and recreated on every cluster rebuild.
        Sid       = "OnlyCIRoleMaySign"
        Effect    = "Deny"
        Principal = "*"
        Action    = "kms:Sign"
        Resource  = "*"
        Condition = {
          StringNotEquals = { "aws:PrincipalArn" = local.signer_role_arn }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "image_signing" {
  name          = "alias/two-tier-image-signing"
  target_key_id = aws_kms_key.image_signing.key_id
}

# The PUBLIC key: safe to share. Used to verify signatures (laptop, Kyverno).
data "aws_kms_public_key" "image_signing" {
  key_id = aws_kms_key.image_signing.arn
}

output "image_signing_key_arn" {
  value = aws_kms_key.image_signing.arn
}

output "image_signing_public_key" {
  description = "Save as cosign.pub; Kyverno uses it in Phase 3"
  value       = data.aws_kms_public_key.image_signing.public_key_pem
}

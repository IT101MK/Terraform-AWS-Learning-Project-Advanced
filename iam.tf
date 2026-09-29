# iam.tf
#
# One IAM role, shared by every host in the fleet. This is a deliberate
# simplification over "one role per host" - it's justified here because
# every host runs the identical nginx + status-page workload and needs the
# identical permissions. If hosts ever diverged in purpose (e.g. one
# becomes a database server), you'd want to split this into per-role
# profiles scoped to what each one actually needs.

resource "aws_iam_role" "fleet" {
  name = "${var.project_name}-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-fleet-role"
  }
}

# Inline policy scoped to exactly one bucket, exactly two actions. Same
# bucket-vs-objects ARN distinction as the base project:
#   - ListBucket is a bucket-level action -> targets the bucket ARN itself
#     (arn:aws:s3:::my-bucket)
#   - Get/PutObject are object-level actions -> target the bucket ARN with
#     a /* suffix (arn:aws:s3:::my-bucket/*)
# Using the wrong ARN shape for either is a common mistake: ListBucket on
# "bucket/*" silently matches nothing, and Get/PutObject on the bare bucket
# ARN is similarly a no-op.
resource "aws_iam_role_policy" "s3_access" {
  name = "${var.project_name}-s3-access"
  role = aws_iam_role.fleet.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListOurBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.data.arn
      },
      {
        Sid      = "ReadWriteObjectsInOurBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.data.arn}/*"
      }
    ]
  })
}

# The one deliberate exception to "inline policies only": SSM Session
# Manager requires the AWS-managed AmazonSSMManagedInstanceCore policy,
# which is broad by design (it has to cover every SSM feature, not just
# the bits we use) and isn't something you'd realistically hand-write as
# an inline policy. Attaching the managed policy here is what lets you
# open a shell on any host via "aws ssm start-session" with no SSH key,
# no open port 22, and no bastion host.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.fleet.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# The instance profile is the container that actually attaches a role to
# an EC2 instance. Shared across the whole fleet, same as the role.
resource "aws_iam_instance_profile" "fleet" {
  name = "${var.project_name}-fleet-profile"
  role = aws_iam_role.fleet.name

  tags = {
    Name = "${var.project_name}-fleet-profile"
  }
}

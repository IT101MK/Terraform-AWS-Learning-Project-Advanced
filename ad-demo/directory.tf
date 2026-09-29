# directory.tf
#
# ============================================================================
# COST AND TIMING WARNING - READ BEFORE APPLYING
# ============================================================================
# AWS Managed Microsoft AD bills HOURLY from the moment this resource is
# created, whether or not you're using it - roughly USD 88/month (approx.
# GBP 65-70) for Standard Edition if left running continuously. This
# config is meant for a short-lived apply -> screenshot -> destroy cycle,
# NOT for something you leave up.
#
# Provisioning typically takes 20-40 minutes to reach "Active" status
# (AWS's own admin guide quotes this range; budget up to 45 to be safe).
# "terraform destroy" takes a similar amount of time to tear the directory
# back down. Budget roughly 1-1.5 hours of wall-clock time for a full
# apply -> screenshot -> destroy cycle, even though the directory is only
# briefly "Active" during that window.
#
# BEFORE YOU APPLY: check the AWS Directory Service console for one-time
# free-trial eligibility. A new-to-the-service account may get a 30-day /
# 1500-directory-controller-hour trial that would cover this entire demo
# at no cost. Don't assume it applies to your account - verify it there.
#
# Regardless of trial status: destroy this immediately after taking your
# screenshot. Don't leave it running "just in case."
# ============================================================================

resource "aws_directory_service_directory" "main" {
  name        = var.directory_name
  short_name  = var.directory_short_name
  password    = var.directory_password
  edition     = var.directory_edition
  type        = "MicrosoftAD"
  description = "Portfolio demo directory - apply, screenshot Active status, destroy immediately."

  vpc_settings {
    vpc_id     = aws_vpc.main.id
    subnet_ids = [aws_subnet.a.id, aws_subnet.b.id]
  }

  tags = {
    Name = "${var.project_name}-directory"
  }
}

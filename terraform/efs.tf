resource "aws_efs_file_system" "eks_efs" {
    creation_toke = "efs-eks-token"
    perfomance_mode = "generalPurpose"
    throughput_mode = "bursting"

    lifecycle_policy {
        transition_to_ia = "AFTER_30_DAYS"
    }

    tags = {
        Name = "${var.cluster_name}_efs"
    }
}

resource "aws_security_group" "efs_sg" {
    name = "eks_efs_sg"
    description = "Allow traffic from eks nodes only"
    vpc_id = aws_vpc.eks_vpc.id

    dynamic "ingress" {
        from_port = 2049
        to_port = 2049
        protocol = "tcp"
        security_groups = [aws_security_group.eks_node_sg.id]
    }

    egress {
        from_port = 2049
        to_port = 2049
        protocol = "tcp"
        security_groups = [aws_security_group.eks_node_sg.id]
    }

    tags = {
        "Name" = "efs_sg"
    }
}

#mount target
resource "aws_efs_mount_target" "efs_mount_targets" {
    count = 2
    file_system_id = aws_efs_file_system.eks_efs.id
    subnet_id = local.public_subnets[count.index]
    security_groups = [aws_security_group.efs_sg.id]
}

#script for mounting efs
resource "null_resource" "generate_efs_mount_script" {
    provisioner "local-exec" {
        command = templatefile("efs_mount.tpl",{
            efs_mount_point = var.efs_mount_point
            file_system_id = local.file_system_id
        })
        interpreter = [
            "bash",
            "-c"
        ]
    }
}

resource "aws_iam_policy" "node_efs_policy" {
    name = "node_efs_policy_${var.cluster_name}"
    path = "/"
    description = "Policy for EKS node to access EFS"

    policy = jsonencode({
        "Statement": [
            {
                "Action": [
                    "elasticfilesystem:DescribeMountTargets",
                    "elasticfilesystem:DescribeFileSystems",
                    "elasticfilesystem:DescribeAccessPoints",
                    "elasticfilesystem:CreateAccessPoint",
                    "elasticfilesystem:DeleteAccessPoint",
                    "ec2:DescribeAvailabilityZones"
                ],
                "Effect": "Allow",
                "Resource": "*",
                "Sid": ""
            }
        ],
        "Version": "2012-10-17"
    })
}
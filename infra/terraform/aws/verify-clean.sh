#!/usr/bin/env bash
# Quét các resource tốn tiền còn sót trong 1 region. Dùng sau mỗi `terraform destroy`.
# Usage: ./verify-clean.sh [profile] [region]
set -uo pipefail

PROFILE="${1:-ticketrush}"
REGION="${2:-ap-southeast-1}"
AWS=(aws --profile "$PROFILE" --region "$REGION" --output text)
dirty=0

check() { # $1 = tên, $2... = lệnh aws trả về danh sách (mỗi dòng 1 resource)
  local name="$1"; shift
  local out
  if ! out="$("$@" 2>&1)"; then
    echo "[LỖI ] $name: $out"; dirty=1; return
  fi
  # AWS CLI text output in "None" khi danh sách rỗng
  out="$(printf '%s' "$out" | tr '\t' '\n' | sed '/^$/d;/^None$/d')"
  if [ -n "$out" ]; then
    echo "[CÒN ] $name:"; printf '%s\n' "$out" | sed 's/^/        /'; dirty=1
  else
    echo "[sạch] $name"
  fi
}

echo "Profile=$PROFILE Region=$REGION"
"${AWS[@]}" sts get-caller-identity --query Arn || { echo "Chưa đăng nhập: aws sso login --profile $PROFILE"; exit 2; }

check "EC2 instances (chưa terminated)" "${AWS[@]}" ec2 describe-instances \
  --filters "Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down" \
  --query 'Reservations[].Instances[].InstanceId'
check "EBS volumes"        "${AWS[@]}" ec2 describe-volumes --query 'Volumes[].VolumeId'
check "EBS snapshots"      "${AWS[@]}" ec2 describe-snapshots --owner-ids self --query 'Snapshots[].SnapshotId'
check "Elastic IPs"        "${AWS[@]}" ec2 describe-addresses --query 'Addresses[].AllocationId'
check "Load Balancers (v2)" "${AWS[@]}" elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn'
check "Load Balancers (classic)" "${AWS[@]}" elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName'
check "NAT Gateways"       "${AWS[@]}" ec2 describe-nat-gateways \
  --filter "Name=state,Values=pending,available,deleting" --query 'NatGateways[].NatGatewayId'
check "RDS instances"      "${AWS[@]}" rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier'
check "RDS snapshots (manual)" "${AWS[@]}" rds describe-db-snapshots --snapshot-type manual --query 'DBSnapshots[].DBSnapshotIdentifier'
# S3 là toàn cầu: chỉ liệt kê bucket của lab (prefix ticketrush-lab)
check "S3 buckets lab (ticketrush-lab*)" "${AWS[@]}" s3api list-buckets \
  --query "Buckets[?starts_with(Name, 'ticketrush-lab')].Name"

echo
if [ "$dirty" -eq 0 ]; then echo "==> SẠCH"; else echo "==> CÒN SÓT RESOURCE, xử lý trước khi kết thúc lab"; exit 1; fi

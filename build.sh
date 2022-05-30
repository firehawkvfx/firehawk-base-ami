#!/bin/bash
set -e
set -x

echo "Building AMI's for deployment..."

function log {
  local -r level="$1"
  local -r message="$2"
  local -r timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info {
  local -r message="$1"
  log "INFO" "$message"
}

function log_warn {
  local -r message="$1"
  log "WARN" "$message"
}

function log_error {
  local -r message="$1"
  log "ERROR" "$message"
}

function error_if_empty {
  if [[ -z "$2" ]]; then
    log_error "$1"
  fi
  return
}

EXECDIR="$(pwd)"
SOURCE=${BASH_SOURCE[0]}   # resolve the script dir even if a symlink is used to this script
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
cd $SCRIPTDIR
# source ../../../../update_vars.sh --sub-script --skip-find-amis
# AMI TAGS
# Get the resourcetier from the instance tag.
# export TF_VAR_instance_id_main_cloud9=$(curl http://169.254.169.254/latest/meta-data/instance-id)
# export TF_VAR_resourcetier="$(aws ec2 describe-tags --filters Name=resource-id,Values=$TF_VAR_instance_id_main_cloud9 --out=json|jq '.Tags[]| select(.Key == "resourcetier")|.Value' --raw-output)" # Can be dev,green,blue,main.  it is pulled from this instance's tags by default
export PKR_VAR_resourcetier="$TF_VAR_resourcetier"
export PKR_VAR_ami_role="firehawk-base-ami"
export PKR_VAR_commit_hash="$(git rev-parse HEAD)"
export PKR_VAR_commit_hash_short="$(git rev-parse --short HEAD)"

# Packer Vars
export PKR_VAR_aws_region="$AWS_DEFAULT_REGION"
export PACKER_LOG=1
export PACKER_LOG_PATH="$SCRIPTDIR/packerlog.log"
export PKR_VAR_manifest_path="$SCRIPTDIR/manifest.json"

mkdir -p $SCRIPTDIR/tmp/log
rm -f $PKR_VAR_manifest_path

ls

build_list="amazon-ebs.ubuntu18-ami,\
amazon-ebs.amazonlinux2-ami,\
amazon-ebs.amazonlinux2-nicedcv-nvidia-ami,\
amazon-ebs.centos7-ami,\
amazon-ebs.base-openvpn-server-ami"

missing_images_for_hash=$(aws ec2 describe-images --owners self --filters "Name=tag:commit_hash_short,Values=[$PKR_VAR_commit_hash_short]" --query "Images[*].{ImageId:ImageId,date:CreationDate,Name:Name,SnapshotId:BlockDeviceMappings[0].Ebs.SnapshotId,commit_hash_short:[Tags[?Key=='commit_hash_short']][0][0].Value,packer_source:[Tags[?Key=='packer_source']][0][0].Value}" \
| jq -r '
  .[].packer_source' \
| jq --arg BUILDLIST "$build_list" --slurp --raw-input 'split("\n")[:-1] as $existing_names 
| ($existing_names | unique) as $existing_names_set
| ($BUILDLIST | split(",") | unique) as $intended_names_set
| $intended_names_set - $existing_names_set
')

count_missing_images_for_hash=$(jq -n --argjson data "$missing_images_for_hash" '$data | length')

if [[ "$count_missing_images_for_hash" -eq 0 ]]; then
  echo "All images have already been built for this hash and build list."
  echo
  echo "To force a build, ensure at least one image from the build list is missing.  The builder will erase all images for the commit hash and rebuild."

  cd $EXECDIR
  set +e
  exit 0
fi

echo "The following images have not yet been built:"
echo "$missing_images_for_hash"
echo "Packer will erase all images for this commit hash and rebuild all images"

$SCRIPTDIR/delete-all-old-amis.sh --commit-hash-short-list $PKR_VAR_commit_hash_short --auto-approve

# Validate
packer validate "$@" -var "ca_public_key_path=$HOME/.ssh/tls/ca.crt.pem" \
  -only=$build_list \
  $SCRIPTDIR/firehawk-base-ami.pkr.hcl

# Build
packer build "$@" -var "ca_public_key_path=$HOME/.ssh/tls/ca.crt.pem" \
  -only=$build_list \
  $SCRIPTDIR/firehawk-base-ami.pkr.hcl

cd $EXECDIR
set +e

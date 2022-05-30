#!/bin/bash
set -e
# set -x

# Header to get this script's path
EXECDIR="$(pwd)"
SOURCE=${BASH_SOURCE[0]}   # resolve the script dir even if a symlink is used to this script
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
  SOURCE=$(readlink "$SOURCE")
  [[ $SOURCE != /* ]] && SOURCE=$DIR/$SOURCE # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPTDIR=$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)
cd $SCRIPTDIR


### Vars
build_list="amazon-ebs.ubuntu18-ami,\
amazon-ebs.amazonlinux2-ami,\
amazon-ebs.centos7-ami,\
amazon-ebs.base-openvpn-server-ami"

# amazon-ebs.amazonlinux2-nicedcv-nvidia-ami,\

export PKR_VAR_resourcetier="$TF_VAR_resourcetier"
export PKR_VAR_ami_role="firehawk-base-ami"
export PKR_VAR_commit_hash="$(git rev-parse HEAD)"
export PKR_VAR_commit_hash_short="$(git rev-parse --short HEAD)"
export PKR_VAR_aws_region="$AWS_DEFAULT_REGION"
export PACKER_LOG=1
export PACKER_LOG_PATH="$SCRIPTDIR/packerlog.log"
export PKR_VAR_manifest_path="$SCRIPTDIR/manifest.json"

echo "Building AMI's for deployment: $PKR_VAR_ami_role"

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


### Idempotency logic: exit if all images exist
error_if_empty "Missing: PKR_VAR_commit_hash_short:" "$PKR_VAR_commit_hash_short"
error_if_empty "Missing: build_list:" "$build_list"

ami_query=$(aws ec2 describe-images --owners self --filters "Name=tag:commit_hash_short,Values=[$PKR_VAR_commit_hash_short]" --query "Images[*].{ImageId:ImageId,date:CreationDate,Name:Name,SnapshotId:BlockDeviceMappings[0].Ebs.SnapshotId,commit_hash_short:[Tags[?Key=='commit_hash_short']][0][0].Value,packer_source:[Tags[?Key=='packer_source']][0][0].Value}")

total_built_images=$(echo $ami_query | jq -r '. | length')

missing_images_for_hash=$(echo $ami_query \
| jq -r '
  .[].packer_source' \
| jq --arg BUILDLIST "$build_list" --slurp --raw-input 'split("\n")[:-1] as $existing_names 
| ($existing_names | unique) as $existing_names_set
| ($BUILDLIST | split(",") | unique) as $intended_names_set
| $intended_names_set - $existing_names_set
')

count_missing_images_for_hash=$(jq -n --argjson data "$missing_images_for_hash" '$data | length')

if [[ "$count_missing_images_for_hash" -eq 0 ]]; then
  echo
  echo "All images have already been built for this hash and build list."
  echo "To force a build, ensure at least one image from the build list is missing.  The builder will erase all images for the commit hash and rebuild."
  echo

  cd $EXECDIR
  set +e
  exit 0
fi


### Packer profile
# export PKR_VAR_provisioner_iam_profile_name="$(terragrunt output instance_profile_name)"
echo "Using profile: $PKR_VAR_provisioner_iam_profile_name"
error_if_empty "Missing: PKR_VAR_provisioner_iam_profile_name" "$PKR_VAR_provisioner_iam_profile_name"


# If sourced, dont execute
(return 0 2>/dev/null) && sourced=1 || sourced=0
echo "Script sourced: $sourced"
if [[ ! "$sourced" -eq 0 ]]; then
  cd $EXECDIR
  set +e
  exit 0
fi

echo "The following images have not yet been built:"
echo "$missing_images_for_hash"

echo "total_built_images: $total_built_images"
if [[ $total_built_images -gt 0 ]]; then
  echo "Packer will erase all images for this commit hash and rebuild all images"
  $SCRIPTDIR/delete-all-old-amis.sh --commit-hash-short-list $PKR_VAR_commit_hash_short --auto-approve
fi

# Validate
packer validate "$@" \
  -only=$build_list \
  $SCRIPTDIR/firehawk-base-ami.pkr.hcl

# Prepare for build.
# Ansible log path
mkdir -p "$SCRIPTDIR/tmp/log"
# Clear previous manifest
rm -f $PKR_VAR_manifest_path

# Build
packer build "$@" \
  -only=$build_list \
  $SCRIPTDIR/firehawk-base-ami.pkr.hcl

cd $EXECDIR
set +e

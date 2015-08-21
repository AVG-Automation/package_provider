#!/bin/bash

set -e
[ -n "$ENV" -a "$ENV" != 'production' ] && set -x

if [ -z "$1" ]; then
  echo "$0 repo_url repo_cache_local_folder"
  echo
  echo "Clones repo from specified URL or cached folder and sets its origin."
  exit 1
fi

repo_url=$1
clone_from=${2:-$repo_url} #take 2nd arg if present otherwise repo_url

git clone -l --no-checkout $clone_from . # ${pwd}
git remote set-url origin $repo_url
git config core.sparsecheckout true
git config gc.auto 0

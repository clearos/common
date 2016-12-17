#!/bin/bash

which git >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo 'You need git in PATH' >&2
    exit 1
fi

which curl >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    echo 'You need curl in PATH' >&2
    exit 1
fi

# should go into a function section at some point
weakHashDetection () {
  strHash=${1};
  case $((`echo ${strHash}|wc -m` - 1 )) in
    128)
      hashBin='sha512sum'
      ;;
    64)
      hashBin='sha256sum'
      ;;
    40)
      hashBin='sha1sum'
      ;;
    32)
      hashBin='md5sum'
      ;;
    *)
      hashBin='unknown'
      ;;
  esac
  echo ${hashBin};
}

# check metadata file and extract package name
shopt -s nullglob
set -- .*.metadata
if (( $# == 0 ))
then
    echo 'Missing metadata. Please run from inside a sources git repo' >&2
    exit 1
elif (( $# > 1 ))
then
    echo "Warning: multiple metadata files found. Using $1"
fi
meta=$1
pn=${meta%.metadata}
pn=${pn#.}

if [ ! -d .git ] || [ ! -d SPECS ]; then
  echo 'You need to run this from inside a sources git repo' >&2
  exit 1
fi
mkdir -p SOURCES

# generate a list of all branches containing current HEAD
branches=()
while IFS='' read -r line
do
  # input from: git branch --all --contains HEAD
  branch="${line:2}"
  # switch clear/infra to c
  branch="${branch/clear/c}"
  branch="${branch/infra/c}"
  [ "$branch" = "master" ] && continue
  [[ "$branch" =~ "detached from" ]] && continue
  if [ ".${line:0:1}" = ".*" ]
  then
    # current branch, put it first
    branches=("$branch" "${branches[@]}")
  else
    branches=("${branches[@]}" "$branch")
  fi
done <<< "$(git branch --all --contains HEAD)"

while read -r fsha fname ; do
  if [ ".${fsha}" = ".da39a3ee5e6b4b0d3255bfef95601890afd80709" ]; then
    # zero byte file
    touch ${fname}
  else
    hashType=$(weakHashDetection ${fsha})
    if [ "${hashType}" == "unknown" ]; then
      echo 'Failure: Hash type unknown.' >&2
      exit 1;
    else
      which ${hashType} >/dev/null 2>&1
      if [[ $? -ne 0 ]]; then
        echo "Failure: You need ${hashType} in PATH." >&2
        exit 1;
      fi
    fi
    if [ ! -e "${fname}" ]; then
      for br in "${branches[@]}"
      do
        [ -z "${fsha}" ] && continue
        br=$(echo ${br}| sed -e s'|remotes/origin/||')
        curl -f "https://git.centos.org/sources/${pn}/${br}/${fsha}" -o "${fname}" && break
      done
    else
      echo "${fname} exists. skipping"
    fi
    downsum=$(${hashType} ${fname} | awk '{print $1}')
    if [ "${fsha}" != "${downsum}" ]; then
        rm -f ${fname}
        echo "Failure: ${fname} hash does not match hash from the .metadata file" >&2
        exit 1;
    fi
  fi
done < "${meta}"

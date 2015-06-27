#!/bin/bash
#
# Might want to drop this in ~/bin/ and chmod u+x it
#

#  Initial Author: Karanbir Singh <kbsingh@centos.org>
#         Updates:
#                  Mike McLean <mikem@redhat.com>
#                  Pat Riehecky <riehecky@fnal.gov>
#                  Tyler Parsons <tparsons@fnal.gov>


#####################################################################
usage() {
    echo ''                                               >&2
    echo "$0 [-hcq] [-b branch] [--surl url]"             >&2
    echo ''                                               >&2
    echo 'Script to parse the non-text sources metadata file'   >&2
    echo ' and download the required files from the lookaside'  >&2
    echo ' cache.'                                              >&2
    echo ''                                                     >&2
    echo 'PLEASE NOTE: this script is non-destructive, it wont' >&2
    echo ' replace files that already exist, regardless of'     >&2
    echo ' their state, allowing you to have work-in-progress'  >&2
    echo ' content that wont get overwritten.'                  >&2
    echo ''                                                     >&2
    echo 'You need to run this from inside a sources git repo'  >&2
    echo ''                                               >&2
    echo ' -h: This help message'                         >&2
    echo ''                                               >&2
    echo "  $0 -b c7"                                     >&2
    echo "  $0 -q -b c7"                                  >&2
    echo "  $0 -c -b remotes/origin/c7"                   >&2
    echo "  $0 -c -b c7 --surl '$SURL'"                   >&2
    echo "  $0"                                           >&2
    exit 1
}

#####################################################################

SURL="https://git.centos.org/sources/"

QUIET=0
BRANCH=''
CHECK=0

# for setting any overrides, such as SURL, default BRANCH, or force CHECK
if [ -f /etc/centos-git-common ]; then
  . /etc/centos-git-common
fi

#####################################################################
# setup args in the right order for making getopt evaluation
# nice and easy.  You'll need to read the manpages for more info
# utilizing 'while' construct rather than 'for arg' to avoid unnecessary
# shifting of program args
args=$(getopt -o hcqb: -l surl: -- "$@")
eval set -- "$args"

while [[ 0 -eq 0 ]]; do
    case $1 in
        -- )
            # end of getopt args, shift off the -- and get out of the loop
            shift
            break
           ;;
         -c )
            # verify the sha1sum of the downloaded file
            CHECK=1
            shift
           ;;
         -q )
            # suppress warnings
            QUIET=1
            shift
           ;;
         -b )
            # Check this particular branch 
            BRANCH=$2
            shift
            shift
           ;;
         --surl )
            # override sources url
            SURL=$2
            shift
            shift
           ;;
         -h )
            # get help
            usage
           ;;
    esac
done

# set curl options this way so defaults can be set in /etc/centos-git-common
# across multiple scripts
if [[ ${QUIET} -eq 1 ]]; then
    QUIET='--silent'
else
    QUIET=''
fi

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

# sort out our branch
if [ -n "$BRANCH" ]
then
  branches=("$BRANCH")
else
  # generate a list of all branches containing current HEAD
  branches=()
  while IFS='' read -r line
  do
    # input from: git branch --contains HEAD
    branch="${line:2}"
    # switch clear to c
    branch="${branch/clear/c}"
    if [[ "$branch" =~ "detached from" ]]
    then
      # ignore detached heads
      continue
    fi
    if [ ".${line:0:1}" = ".*" ]
    then
      # current branch, put it first
      branches=("$branch" "${branches[@]}")
    else
      branches=("${branches[@]}" "$branch")
    fi
  done <<< "$(git branch --contains HEAD)"
fi
while read -r fsha fname ; do
  if [ ".${fsha}" = ".da39a3ee5e6b4b0d3255bfef95601890afd80709" ]; then
    # zero byte file
    touch ${fname}
  else
    if [ ${CHECK} -eq 1 ]; then
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
    fi
    if [ ! -e "${fname}" ]; then
      for br in "${branches[@]}"
      do
        [ -z "${fsha}" ] && continue
        br=$(echo ${br}| sed -e s'|remotes/origin/||')
        curl ${QUIET} -f "${SURL}/${pn}/${br}/${fsha}" -o "${fname}" && break
      done
    else
      echo "${fname} exists. skipping"
    fi
    if [ ${CHECK} -eq 1 ]; then
        downsum=$(${hashType} ${fname} | awk '{print $1}')
        if [ "${fsha}" != "${downsum}" ]; then
            rm -f ${fname}
            echo "Failure: ${fname} hash does not match hash from the .metadata file" >&2
            exit 1;
        fi
    fi
  fi
done < "${meta}"

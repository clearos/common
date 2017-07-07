#!/bin/bash

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

# check sources-clearos file and extract package name
if [ ! -f sources-clearos2 ]
then
    echo 'Missing sources-clearos2. Please run from inside a sources git repo' >&2
    exit 1
fi

# check metadata file and extract package name
shopt -s nullglob
set -- *.spec
if (( $# == 0 ))
then
    echo 'Missing SPEC file. Please run from inside a sources git repo' >&2
    exit 1
elif (( $# > 1 ))
then
    echo "Warning: multiple SPEC files found. Using $1"
fi
pn=$1
pn=${pn%.spec}
# Remove webconfig from front of package name
pn=${pn#webconfig-}

if [ ! -d .git ]; then
  echo 'You need to run this from inside a sources git repo' >&2
  exit 1
fi

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
      [ -z "${fsha}" ] && continue
      curl -f "http://buildsys.clearfoundation.com/source/${fsha}/${fname}" -o "${fname}"
    else
      echo "${fname} exists. skipping"
    fi
    downsum=$(${hashType} ${fname} | awk '{print $1}')
    if [ "${fsha}" != "${downsum}" ]; then
        rm -f ${fname}
        echo "Failure: ${fname} hash does not match hash from the sources-clearos2 file" >&2
        exit 1;
    fi
  fi
done < sources-clearos2

#!/bin/bash
# Copyright (C) 2019 hsj51
#
# Licensed under the Raphielscape Public License, Version 1.b (the "License");
# you may not use this file except in compliance with the License.
#
# CI Runner Script for Building a ROM

# We need this directive
# shellcheck disable=1090


##### Build Env Dependencies
build_env()
{
cd
git clone https://github.com/akhilnarang/scripts > /dev/null 2>&1
cd scripts
bash setup/android_build_env.sh  > /dev/null 2>&1
echo "Build Dependencies Installed....."
sudo unlink /usr/bin/python
curl -sLo upload-github-release-asset.sh https://gist.githubusercontent.com/stefanbuck/ce788fee19ab6eb0b4447a85fc99f447/raw/dbadd7d310ce8446de89c4ffdf1db0b400d0f6c3/upload-github-release-asset.sh
sudo apt-get install p7zip-full p7zip-rar wget curl brotli -y > /dev/null 2>&1
sudo ln -s /usr/bin/python2.7 /usr/bin/python
cd $path
rm -rf scripts

git clone https://hsj51:${GH_PERSONAL_TOKEN}@github.com/hsj51/google-git-cookies.git > /dev/null 2>&1
cd google-git-cookies
bash run.sh
cd $path
rm -rf google-git-cookies

git config --global user.email "hrutvikjagtap51@gmail.com"
git config --global user.name "hsj51"
git config --global color.ui "auto"

echo "Google Git Cookie Set!"
}

cyan=' '
yellow=' '
reset=' '

validate_arg() {
    valid=$(echo $1 | sed s'/^[\-][a-z0-9A-Z\-]*/valid/'g)
    [ "x$1" == "x$0" ] && return 0;
    [ "x$1" == "x" ] && return 0;
    [ "$valid" == "valid" ] && return 0 || return 1;
}

function dogbin()
{
  # Usage: dogbin <file> or | dogbin (Share dogbin logs)

  # Based upon the haste function above

  # Variables
  local tmp;
  local url;

  # Get output
  tmp=$(mktemp);
  if [ ! -z "${1}" ] && [ -f "${1}" ]; then
    tee "${tmp}" < "${1}";
  else
    cat | tee "${tmp}";
  fi;
  echo '';

  # Trim line rewrites
  edittrimoutput "${tmp}";

  # Upload to dogbin
  url="http://del.dog/$(timeout -k 10 10 curl -X POST -s --data-binary @"${tmp}" \
      https://del.dog/documents | grep key | cut -d \" -f 4)";
  echo " dogbin: ${url}";

  # delete temp file
  rm "${tmp}";
  echo ${url} > /tmp/dogbin_url
}

function edittrimoutput()
{
  # Usage
  if [ -z "${1}" ]; then
    echo '';
    echo ' Usage: edittrimoutput <"files"> (Edit by triming output line rewrites)';
    echo '';
    return;
  fi;

  # Trim output line rewrites
  sed -i 's/\r[^\n]*\r/\r/g' "${@}";
  sed -i 's/\(\r\|'$'\033''\[K\)//g' "${@}";
  sed -Ei 's/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g' "${@}";
}


print_help() {
    echo "Usage: `basename $0` [OPTION]";
    echo "  -i, --init-source \ Declare you need repo init" ;
    echo "  -U, --url \ Supply Repo Init URL" ;
    echo "  -b, --branch \ Supply branch to sync" ;
    echo "  -s, --sync-android \ Sync current source" ;
    echo "  -b, --brand \ Brand name" ;
    echo "  -d, --device \ Device name" ;
    echo "  -dt --device-tree \ Specify Device Tree for unofficial build" ;
    echo "  -t, --target \ Make target" ;
    echo "  -c, --clean \ Clean target" ;
    echo "  -ca, --cleanall \ Clean entire out" ;
    echo "  -tg, --telegram \ Enable telegram message" ;
    echo "  -u, --upload \ Enable drive upload" ;
    echo "  -r, --Release \ Enable drive upload, tg msg and clean" ;
    exit
}

prev_arg=
while [ "$1" != "" ]; do
    cur_arg=$1

    # find arguments of the form --arg=val and split to --arg val
    if [ -n "`echo $cur_arg | grep -o =`" ]; then
        cur_arg=`echo $1 | cut -d'=' -f 1`
        next_arg=`echo $1 | cut -d'=' -f 2`
    else
        cur_arg=$1
        next_arg=$2
    fi

    case $cur_arg in

        -i | --init-source )
            prepare_source_scr=$next_arg
            ;;
        -U | --url )
            repo_init_url=$next_arg
            ;;
        -B | --branch )
            repo_branch=$next_arg
            ;;
        -s | --sync-android )
            sync_android_scr=1
            ;;
        -b | --brand )
            brand_scr=$next_arg
            export brand_scr
            ;;
        -d | --device )
            device_scr=$next_arg
            export device_scr
            ;;
        -t | --target )
            build_type_scr=$next_arg
            build_orig_scr=$next_arg
            ;;
        -tg | --telegram )
            telegram_scr=1
            ;;
        -u | --upload )
            upload_scr=1
            ;;
        -dt | --device-tree )
            device_tree=$next_arg
            ;;

        -r | --release )
            telegram_scr=1
            upload_scr=1
            clean_scr=1
            ;;
        -c | --clean )
            clean_scr=1
            ;;
        -ca | --clean-all )
            cleanall_scr=1
            ;;
        *)
            validate_arg $cur_arg;
            if [ $? -eq 0 ]; then
                echo "Unrecognised option $cur_arg passed"
                print_help
            else
                validate_arg $prev_arg
                if [ $? -eq 1 ]; then
                    echo "Argument $cur_arg passed without flag option"
                    print_help
                fi
            fi
            ;;
    esac
    prev_arg=$1
    shift
done

acquire_build_lock() {

    lock_name="android_build_lock"
    lock="$HOME/${lock_name}"

    exec 200>${lock}

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Attempting to acquire lock $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)

    # loop if we can't get the lock
    while true; do
        flock -n 200
        if [ $? -eq 0 ]; then
            break
        else
            printf "%c" "."
            sleep 5
        fi
    done

    # set the pid
    pid=$$
    echo ${pid} 1>&200

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Lock $($yellow)${lock}$($cyan) acquired. PID is $($yellow)${pid}$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
}

remove_build_lock() {
    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Removing $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
    exec 200>&-
}

prepare_source() {

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Initializing $($yellow)$prepare_source_scr$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
    source_android_scr=$prepare_source_scr
    repo init -u $repo_init_url -b $repo_branch --depth 1
    sync_android_scr=1
    ##### if this fails idc, its your problem biatch
}

function_check() {
    if [ ! $TELEGRAM_TOKEN ] && [ ! $TELEGRAM_CHAT ]; then
        printf "You don't have TELEGRAM_TOKEN,TELEGRAM_CHAT set"
        exit
    fi


    if [ ! -f telegram ];
    then
        echo "Telegram binary not present. Installing.."
        wget -q https://raw.githubusercontent.com/Dyneteve/misc/master/telegram
        chmod +x telegram
    fi

    if [ ! -d $HOME/buildscript ];
    then
        mkdir $HOME/buildscript
    fi
}

sync_source() {
    if [ $sync_android_scr ]; then
      printf "%s\n\n" $($cyan)
      printf "%s\n" "*********************************************"
      printf '%s\n' "Repo Sync Started"
      printf "%s\n" "*********************************************"
      printf "%s\n\n" $($reset)
      # Reset bash timer and begin syncing
      SECONDS=0
      bash telegram -M "Sync Started for $repo_init_url "
      repo sync --force-sync --current-branch --no-tags --no-clone-bundle --optimized-fetch --prune -j$(nproc --all) -q > sync.log 2>&1
      dogbin sync.log
      printf "%s\n\n" $($cyan)
      printf "%s\n" "*********************************************"
      printf '%s\n' "Repo Sync Finished"
      printf "%s\n" "*********************************************"
      printf "%s\n\n" $($reset)
    fi
}

start_env() {
    rm -rf venv
    virtualenv2 venv
    source venv/bin/activate
}

setup_paths() {
    source build/envsetup.sh
  ####### Workaround the Missing Lunch combos for official trees
  if [ $prepare_source_scr ]; then
    printf "%s\n\n" $($cyan)
    printf "%s\n" "***************************************"
    printf '%s\n' "Breakfasting device trees from rom repo"
    printf "%s\n" "***************************************"
    printf "%s\n\n" $($reset)
    if ! breakfast "${device_scr}"; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "*****************************************************"
        printf '%s\n' "Breakfast failed! Lunching device trees from rom repo"
        printf "%s\n" "*****************************************************"
        printf "%s\n\n" $($reset)
        lunch "$prepare_source_scr"_"$device_scr"-userdebug
    fi
    OUT_SCR=out/target/product/$device_scr
    DEVICEPATH_SCR=device/$brand_scr/$device_scr

    if [ $prepare_source_scr ] && [ ! -d $DEVICEPATH_SCR ]; then
      if [ $device_tree ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Unofficial Device Tree Detected"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        git clone $device_tree device/$brand/$device
        python3 unofficial_builder.py
        lunch "$prepare_source_scr"_"$device_scr"-userdebug
      else
        printf "%s\n Couldnt fetch DT"
        exit
      fi
    fi
    if [ -z "$build_type_scr" ]; then
        build_type_scr=bacon
    fi
  fi
}

clean_target() {
    if [ $clean_scr ] && [ ! $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning target $($yellow) $device_scr $($cyan)"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf $OUT_SCR
        sleep 2
    elif [ $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning entire out"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf out
        sleep 2s
    fi
}

upload() {
#    if [ $telegram_scr ] && [ ! $(grep -c "#### build completed successfully" build.log) -eq 1 ]; then
#      bash telegram -D -M "
#      *Build for $device_scr failed!*"
#      bash telegram -f build.log
#      exit
#    fi
    case $build_type_scr in
        bacon)
            file=$(ls $OUT_SCR/*201*.zip | tail -n 1)
    esac

    if [ -f $HOME/buildscript/*.img ]; then
        rm -f $HOME/buildscript/*.img
    fi
    git clone https://github.com/jazz511/Generic-ROM-Builder -b binary binary
    cd binary
    touch "$(date +%d%m%y)-${prepare_source_scr}-$DRONE_BUILD_NUMBER"
    git add .
    git commit -m "[HrutvikCI]: Releasing Build ${prepare_source_scr}-$(date +%d%m%y)"
    git tag "$(date +%d%m%y)-${prepare_source_scr}-$DRONE_BUILD_NUMBER"
    git remote rm origin
    git remote add origin https://hsj51:${GH_PERSONAL_TOKEN}@github.com/hsj51/rom_releases.git
    git push origin binary --follow-tags
    build_date_scr=$(date +%F_%H-%M)
    if [ ! -z $build_orig_scr ] && [ $upload_scr ]; then
      bash upload-github-release-asset.sh github_api_token=$GH_PERSONAL_TOKEN owner=hsj51 repo=$GH_REPO_NAME tag="$(date +%d%m%y)-${prepare_source_scr}-$DRONE_BUILD_NUMBER" filename=$file
        file=`ls $HOME/buildscript/*.img | tail -n 1`
        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
    elif [ -z $build_orig_scr ] && [ $upload_scr ]; then
        bash upload-github-release-asset.sh github_api_token=$GH_PERSONAL_TOKEN owner=hsj51 repo=$GH_REPO_NAME tag="$(date +%d%m%y)-${prepare_source_scr}-$DRONE_BUILD_NUM" filename=$file
    fi

    if [ $telegram_scr ] && [ $upload_scr ]; then
        bash telegram -D -M "
        *Build for $device_scr done!*
        Download from Github Releases"
    fi
}

build() {
#  if [ -f build.log ]; then
#      rm -f build.log
#  fi
    if [ -f out/.lock ]; then
        rm -f out/.lock
    fi
    export USE_CCACHE=0
    cd $DEVICEPATH_SCR
    mk_scr=`grep .mk AndroidProducts.mk | cut -d "/" -f "2"`
    product_scr=`grep "PRODUCT_NAME :=" $mk_scr | cut -d " " -f 3`
    cd ../../..

    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Started build with target $($yellow)"$build_type_scr""$($cyan)" for"$($yellow)" $device_scr $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2

    if [ "$telegram_scr" ]; then
        bash telegram -D -M "
        *Build for $device_scr started!*
        Product: *$product_scr*
        Target: *$build_type_scr*
        Started on: *$HOSTNAME*
        Time: *$(date "+%r")* "
    fi
    SECONDS=0
    mka bacon | grep $device_scr
    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Finished build with target $($yellow)"$build_type_scr""$($cyan)" for"$($yellow)" $device_scr $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2
}

build_env
if [ ! -z "$device_scr" ] && [ ! -z "$brand_scr" ]; then
    acquire_build_lock
if [ $prepare_source_scr ]; then
    prepare_source
fi
    function_check
#    start_env
    sync_source
  if [ -e frameworks/base ]; then
    bash telegram -N -M "Sync completed successfully in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    setup_paths
    clean_target
    build $brand_scr $device_scr
      if [ -e "$finalzip_path" ]; then
        bash telegram -N -M "Build completed successfully in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
      else
        bash telegram -N -M "Build failed in $((BUILD_DIFF / 60)) minute(s) and $((BUILD_DIFF % 60)) seconds"
        exit 1
      fi
    remove_build_lock
    upload
  else
    echo "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds"
    bash telegram -N -M "Sync failed in $((SYNC_DIFF / 60)) minute(s) and $((SYNC_DIFF % 60)) seconds
    See [logs here]($(cat /tmp/dogbin_url))"
    exit 1
  fi
else
    print_help
fi

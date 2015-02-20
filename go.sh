#!/usr/bin/env bash

#                              888
#                              888
#                              888
#  .d88b.   .d88b.     .d8888b  88888b.
# d88P"88b d88""88b    88K      888 "88b
# 888  888 888  888    "Y8888b. 888  888
# Y88b 888 Y88..88P d8b     X88 888  888
#  "Y88888  "Y88P"  Y8P 88888P' 888  888
#      888
# Y8b d88P
#  "Y88P"
#
# go.sh - a helper script to make managing go environments a bit easier

# Licensed under the BSD 3-Clause License, see the LICENSE file for more details.
# Developed at Single Platform by:
#   Tristan Fisher (github.com/tfishersp ; github.com/tristanfisher)
#   David Panofsky (github.com/davidpanofsky ; github.com/dpanofsky)


#-------------------------------------------------------------------------------------#
# Script setup

unset _GOPATH
unset _OLD_PATH
_OLD_GOPATH=$GOPATH
_OLD_PATH=$PATH

unset _DEBUG
unset DEBUG
DEBUG="false"

unset PATH_CANDIDATE
_EXIT_CODE=0

#-------------------------------------------------------------------------------------#

function usage(){
    cat << EOF
Usage: $0 [options]

Examples:

  $ go.sh -sp go env
  $ go.sh -sp go build

Options:

  [ Path flags ]
  -gp|--gopath /specific/path/    Instruct go.sh to use the specified GOPATH
  -sp|--shared-gopath             Instruct go.sh to use $HOME/go as a GOPATH
  -pp|--project-gopath            Instruct go.sh to create a GOPATH for the specified
                                  project under $HOME/.go/TARGET [requires --target]
  -gr|--goroot /path/to/go        Instruct go.sh to use the go install specified.
                                  Go officially defaults to /usr/local/go/bin

  [ Build flags ]
  -b|--build                      Get dependencies and build a --target project [requires --target]
  -t|--target                     Specify a target for building or setting a GOPATH [requires --build]

  [ Other flags ]
  -d|--debug                      Instruct go.sh to output debugging information
  -de|--deactivate                Revert an environment to as it was before sourcing go.sh
  -h|--help                       Print this helpful information and exit

EOF
    exit ${_EXIT_CODE:-0}

}

function deactivate(){
    if [ -n "$_OLD_GOPATH" ]; then
        GOPATH=$_OLD_GOPATH
        unset _OLD_GOPATH
        export GOPATH
    fi

    if [ -n "$_OLD_PATH" ]; then
        PATH=$_OLD_PATH
        unset _OLD_PATH
        export PATH
    fi

}

function set_go_path(){

    # If we didn't get a _GOPATH set by some means, default to GOPATH, which
    # could still be empty.
    if [ -z "$_GOPATH" ]; then
        _GOPATH=$GOPATH
    fi


    # Store user shell option for extglob.  Test that shopt is usable first.
    type shopt >> /dev/null
    if [ "$?" -eq 0 ]; then
        _OLD_SHOPT_SETTING=$(shopt extglob | cut -f2)
    fi

    # Clean off trailing slashes..
    shopt -s extglob
    _GOPATH=${_GOPATH%%+(/)}

    # If we don't have a dir at the gopath (and it's set), create it.
    if [ ! -d "$_GOPATH" ]; then
        if [ "$_GOPATH" ]; then
            if $_DEBUG; then
                echo "Making GOPATH directory: $_GOPATH"
            fi
        mkdir -p "$_GOPATH"
        fi
    fi

    # If we're here, we're justified in changing the path.

    # GOPATH - local code and dependencies
    # GOROOT - typically /usr/local/go, or the root of the custom go installation

    GOPATH="$_GOPATH"

    # Set GOROOT.  The path needs to have a go executable:
    if [ -n "$_GOROOT" ]; then
        if [ -d "$_GOROOT" ]; then

            if [ ! -f "$_GOROOT/go" ]; then
                echo "Specified GOROOT (--goroot) does not appear to be valid (missing go executable)"
                exit 1
            fi

        # Clean off trailing slashes..
        _GOROOT=${_GOROOT%%+(/)}
        GOROOT="$_GOROOT"

        else
            echo "Specified GOROOT not a directory."
            exit 1
        fi
    fi

    # $PATH should have the order of $GOPATH/bin:$GOROOT/bin:$PATH
    if [[ ":$PATH:" == *":$GOROOT:"* ]]; then
        if $_DEBUG; then
            echo "GOROOT: $GOROOT already exists in path (not adding)."
        fi
    else
        PATH=$GOROOT:$PATH
    fi

    #Check that the candidate Go bin PATH isn't already in the PATH:
    if [[ ":$PATH:" == *":$GOPATH/bin:"* ]]; then
        if $_DEBUG; then
            echo "GOPATH: $GOPATH/bin already exists in path (not adding)."
        fi
    else
        PATH=$GOPATH/bin:$PATH
    fi

    if [[ ":$PATH:" == *":$GOPATH:"* ]]; then
        if $_DEBUG; then
            echo "GOPATH: $GOPATH already exists in path (not adding)."
        fi
    else
        PATH=$GOPATH:$PATH
    fi

    # Turn shopt back to the way the user had it...
    if [ -n "$_OLD_SHOPT_SETTING" ]; then
        if [ "$_OLD_SHOPT_SETTING" == "off" ]; then
            shopt -u extglob
        fi
    fi

    export PATH
    export GOROOT
    export GOPATH

}


function gopath_homedir_project {

    if [ -z "$_GO_PROJECT" ]; then
        echo "No project (--target) was specified, so we can't autopilot for you on GOPATH settings"
        _EXIT_CODE=1
        usage
    fi

    # If the GO_PROJECT is a file, use its dir name
    if [ -f "$_GO_PROJECT" ]; then
        _PROJECT_NAME="${_GO_PROJECT%/*}"

    elif [ -d "$_GO_PROJECT" ]; then
        #otherwise, use the path given to the project
        _PROJECT_NAME="$_GO_PROJECT"

    else
        # thank the user for the fantastic creativity in files!
        echo "ERROR: did not receive a valid path or file (project) to build.  Expects --target PROJECT"
        exit 1

    fi

    # remove the cmd from the start if it's there, it has special meaning.
    _PROJECT_NAME="${_PROJECT_NAME#cmd/}"

    # After qualifying a useful name, make a dependency dir
    _GOPATH="$HOME/.go/$_PROJECT_NAME"

}

function build(){

    if [ -z ${_GO_PROJECT} ]; then
        echo "Target to build not specified..."
        _EXIT_CODE=1
        usage
    fi

    # Decide what should be our "project folder"
    if [ -d ${_GO_PROJECT} ]; then
        _PROJECT_FOLDER=$_GO_PROJECT
    elif [ -f ${_GO_PROJECT} ]; then
        #Strip filename off end
        _PROJECT_FOLDER="${_GO_PROJECT%/*}"
    else
        echo "ERROR: Specified project (\$1) wasn't file or directory. Giving up."
        exit 1
    fi

    # Decide where to drop the binary file.
    _DEPLOY_DIR="$_PROJECT_FOLDER/deploy"
    if $_DEBUG; then
        echo "Using deploy directory: $_DEPLOY_DIR"
        echo "Building (running 'go get' and 'go build') from project folder: $_PROJECT_FOLDER"

    fi
    mkdir -p "$_DEPLOY_DIR"
    if [ -d "$_PROJECT_FOLDER" ]; then

        # Go into the project folder and run 'go get', 'go build' with a max timeout.
        pushd "$_PROJECT_FOLDER" >> /dev/null

        go_get_process=$({ { go get; } | { sleep 300; kill 0;} } 3>&1)
        if [ $? -ne 0 ]; then
            echo "Failed when attempting to run 'go get' in $_PROJECT_FOLDER"
        fi

        go_build_process=$({ { go build; } | { sleep 300; kill 0;} } 3>&1)
        if [ $? -ne 0 ]; then
            echo "Failed when attempting to run 'go build' in $_PROJECT_FOLDER"
        fi

        popd >> /dev/null

        if [ $? -ne 0 ]; then
            echo "Unknown error happened when attempting to build in $_PROJECT_FOLDER"
        else
            echo "Success! Built: $_GO_PROJECT \n Directory: $_PROJECT_FOLDER \n Binary in: $_DEPLOY_DIR"
        fi

    else
        "Error in build process: (Not a directory) $_PROJECT_FOLDER"
        exit 1
    fi

}


#-------------------------------------------------------------------------------------#


# If user specified args, consider them.
while [[ $# > 0 ]]
do

    _gosh_original_args="$@"

    key="$1"
    shift
    case $key in
        -gp|--gopath)
            _GOPATH="$1"
            set_go_path
        shift
        ;;
        -d|--debug)
            DEBUG="$1"
        shift
        ;;
        -de|--deactivate)
            deactivate
        ;;
        -b|--build)
            build
        ;;
        -t|--target)
            _GO_PROJECT="$1"
        shift
        ;;
        -sp|--shared-gopath)
            # Go project will share deps with other Go projects.
            # This is the way the documentation suggests.
            # The related option, gopath_homedir_project, creates a gopath per project.
            _GOPATH="$HOME/go/"
            set_go_path
        ;;
        -pp|--project-gopath)
            gopath_homedir_project
            set_go_path
        ;;
        -gr|--goroot)
            _GOROOT="$1"
        shift
        ;;
        -h|--help)
            usage
        ;;
        *)
            # not an option we know, so assume user wants to pass through.
            echo "Executing: $_gosh_original_args"

            ($_gosh_original_args)
            _EXIT_CODE=$?

            if [ "$_EXIT_CODE" -ne 0 ]; then
                exit "$_EXIT_CODE"
            fi

            # pop off the rest of the command.
            shift "$#"
        ;;
    esac
done

# ansible 'truthiness' options in case debug is set from a template.
case "$DEBUG" in
    true) _DEBUG=true;;
    TRUE) _DEBUG=true;;
    1) _DEBUG=true;;
    '') _DEBUG=true;;
    false) _DEBUG=false;;
    FALSE) _DEBUG=false;;
    0) _DEBUG=false;;
    *) _DEBUG=false;;
esac


#-------------------------------------------------------------------------------------#
# $GOPATH if sourced:
set_go_path

#-------------------------------------------------------------------------------------#
# Here's your receipt of the minimal actions taken
if $_DEBUG; then
    echo "GOROOT: $GOROOT"
    echo "GOPATH: $GOPATH"
    echo "PATH: $PATH"
fi
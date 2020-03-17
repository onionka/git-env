#!/usr/bin/env bash

function show_help() {
  echo "    How to use git-pr

  Description:
      This program pushes your changes in new branch updated from
      given remote branch.

      These utilities allow to use environment-based branches
      like qa, develop and master (production), so we can
      develop on each of them independently.

  Synopsis:
    $ gitenv [-h|--help] [-v|--verbose] COMMANDS ARGS

  Switches:
    -h|--help                             Shows this help
    -v|--verbose                          Adds a verbose messages

  Parameters:

    COMMANDS                              There are 2 commands that are necessary for developing features:
       push-feature-for TARGET_BRANCHES...   Creates a new branch from current branch, rebases it from BASE_BRANCH
                                             and pushes it to the remote so you can create new PR to the BASE_BRANCH
       create-feature ISSUE TYPE NAME        Creates a new feature from master branch

  Examples:

    To create a new feature from master, use this command:

      $ gitenv create-feature 1234 feat mortgage

    To create a PR branch from current branch to develop, use this command to push new changes into the remote
    and then create PR in github:

      $ gitenv push-feature-for develop

    To create a PR branches in remote for all environments:

      $ gitenv push-feature-for

  Author:

      Miroslav Cibulka <miroslav.cibulka@flowup.cz>
"
  exit 0
}

VISUAL_GUIDE="\e[0;32m>>>\e[0m"

function fmt_bold() {
    echo "\e[1m$@\e[0m"
}

function fmt_italic() {
    echo "\e[3m$@\e[0m"
}

function fmt_error() {
    echo "\e[31;3m$@\e[0m"
}

function fmt_success() {
    echo "\e[32;3m$@\e[0m"
}

function fmt_msg() {
    echo "\e[30;3m$@\e[0m"
}

function fmt_code() {
    echo "'$(fmt_italic $@)'"
}

# Logs message with predefined format
function info() {
    echo -e " ${VISUAL_GUIDE} $@"
}

# Logs error message with predefined format
function error() {
    echo -e " ${VISUAL_GUIDE} $@" >&2
}

# Logs error message with predefined format and exits program
function die() {
    status_code=$1
    shift

    error "$@"

    exit ${status_code}
}

# Helper function that runs commands like git and prints out what is going to happen
function run() {
    info "$(fmt_msg Executing) $(fmt_code $@)"

    if ! $@; then
        status=$?
        die 1 "$(fmt_msg "Command") $(fmt_code $@) $(fmt_error "$(fmt_msg "failed with status") ${status}")"
    fi
}

# Command that creates new branch from master as a feature branch
function create_feature() {
    # Checking the parameters sanity
    if [[ ${#@} -ne 3 ]]; then
        error "$(fmt_error "Expected parameters:") $(fmt_code "gitenv create-feature ISSUE_NUMBER TYPE NAME")"
        die 1 "$(fmt_error "But has:") $(fmt_code "$@")"
    fi

    ISSUE_NUMBER=$1
    TYPE=$2
    NAME=$3

    run git fetch
    run git branch ${ISSUE_NUMBER}-${TYPE}-${NAME} origin/master
    run git checkout ${ISSUE_NUMBER}-${TYPE}-${NAME}

    exit 0
}

# Creates a new branch derived from
function push_feature_for() {
    # Checking the parameters sanity
#    if [[ ${#@} -ne 1 ]]; then
#        error "$(fmt_error "Expected parameters:") $(fmt_code "gitenv push-feature-for BASE_BRANCH")"
#        die 1 "$(fmt_error "But has:") $(fmt_code "$@")"
#    fi

    run git fetch

    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    STASHED=false

    # Stashing unstaged changes
    if ! git diff-index --quiet HEAD --; then
        ${stash} || die 3 "Found unstaged changes, commit/stash/remove them before retrying"
        ${verbose} && info "Found unstaged changed, storing them into the stash"
        run git stash
        STASHED=true
    fi

    # If no params provided, use all environmental branches by default
    if [[ "$@" == "" ]]; then
        TARGET_BRANCHES="develop qa master"
        ${verbose} && info "Using default target branches '${TARGET_BRANCHES}'"
    else
        TARGET_BRANCHES="$@"
    fi

    # Iterating through input environmental branches
    for target_branch in ${TARGET_BRANCHES}; do
        # Checks if provided parameters are valid environmental branches
        if [[ "develop qa master" =~ *${target_branch}* ]]; then
            error "$(fmt_error "Provided target branch is not from environmental branches")"
            error "$(fmt_error "   Input parameters:") $(fmt_code "${target_branch}")"
            die 2 "$(fmt_error "   Expected values:") $(fmt_code "develop qa master")"
        fi

        GIT_PUSH_FLAGS=
        COMMITS=$(git log --left-right --cherry-pick --oneline --format='%H' ${BRANCH}...origin/master \
                  | tr '\n' ' '  \
                  | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')

        # Creating new branch with -${target_branch} suffix, or switching to the existing one
        if ! git show-ref --verify --quiet refs/heads/${BRANCH}-${target_branch}; then
            info "Branch ${BRANCH}-${target_branch} doesn't exists, creating new one"
            run git checkout -b ${BRANCH}-${target_branch}
        else
            info "Branch ${BRANCH}-${target_branch} exists, moving everything there from branch ${BRANCH}"
            run git checkout ${BRANCH}-${target_branch}
            GIT_PUSH_FLAGS="${GIT_PUSH_FLAGS} --force"
        fi

        # Updating branch
        run git reset --hard ${target_branch}
        run git cherry-pick ${COMMITS}

        # Pushing and returning back to the original branch
        run git push origin ${BRANCH}-${target_branch} ${GIT_PUSH_FLAGS}
    done

    # get back to the feature branch
    run git checkout ${BRANCH}

    # Popping stashed unstaged changes
    if ${stash} && ${STASHED}; then
        ${verbose} && info "Popping unstaged changes from stash"
        run git stash pop
    fi

    exit 0
}

verbose=false
stash=false

# Flag processing, this will only search for flags before command
for arg in $@; do
    case "$arg" in
        -h|--help)
            show_help
            shift
            ;;
        -v|--verbose)
            verbose=true
            shift
            ;;
        -s|--stash)
            stash=true
            shift
            ;;
        *)
            # Stops at the first unknown parameter
            break
            ;;
    esac
done

# Processing arguments
if [[ ${#@} -lt 1 ]]; then
  die 1 "Expected parameters: COMMAND ARGS..."
fi

case "$1" in
    create-feature)
        shift
        create_feature $@
        ;;
    push-feature-for)
        shift
        push_feature_for $@
        ;;
    *)
        die 1 "Unknown argument $(fmt_code $1)"
        ;;
esac

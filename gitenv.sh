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
    -h|--help                       Shows this help
    -v|--verbose                    Adds a verbose messages

  Parameters:

    COMMANDS                        There are 2 commands that are necessary for developing features:
       push-feature-for BASE_BRANCH     Creates a new branch from current branch, rebases it from BASE_BRANCH
                                        and pushes it to the remote so you can create new PR to the BASE_BRANCH
       create-feature ISSUE TYPE NAME   Creates a new feature from master branch

  Examples:

    To create a new feature from master, use this command:

      $ gitenv create-feature 1234 feat mortgage

    To create a PR from current branch to develop, use this command to push new changes into the remote
    and then create PR in github:

      $ gitenv push-feature-for develop

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

    error $@

    exit ${status_code}
}

# Helper function that runs commands like git and prints out what is going to happen
function run() {
    if ${verbose}; then
        info "$(fmt_msg Executing) $(fmt_code $@)"
    fi

    if ! $@; then
        status=$?
        if ${verbose}; then
            die 1 "$(fmt_msg "Command") $(fmt_code $@) $(fmt_error "$(fmt_msg "failed with status") ${status}")"
        fi
        exit 1
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
    if [[ ${#@} -ne 1 ]]; then
        error "$(fmt_error "Expected parameters:") $(fmt_code "gitenv push-feature-for BASE_BRANCH")"
        die 1 "$(fmt_error "But has:") $(fmt_code "$@")"
    fi

    PUSH_FLAGS=
    TARGET_BRANCH=$1
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMITS=$(git log --left-right --cherry-pick --oneline --format='%H' ${BRANCH}...master \
              | tr '\n' ' '  \
              | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')
    STASHED=false

    run git fetch

    # Stashing unstaged changes
    if git diff-index --quiet HEAD --; then
        info "Found unstaged changed, storing them into the stash"
        run git stash
        STASHED=true
    fi

    # Creating new branch with -TARGET_BRANCH suffix, or switching to the existing one
    if ! git show-ref --verify --quiet refs/heads/${BRANCH}-${TARGET_BRANCH}; then
        info "Branch ${BRANCH}-${TARGET_BRANCH} doesn't exists, creating new one"
        run git checkout -b ${BRANCH}-${TARGET_BRANCH}
    else
        info "Branch ${BRANCH}-${TARGET_BRANCH} exists, moving everything there from branch ${BRANCH}"
        run git checkout ${BRANCH}-${TARGET_BRANCH}
        PUSH_FLAGS="${PUSH_FLAGS} --force"
    fi

    # Updating branch
    run git reset --hard ${TARGET_BRANCH}
    run git cherry-pick ${COMMITS}

    # Pushing and returning back to the original branch
    run git push origin ${BRANCH}-${TARGET_BRANCH}  ${PUSH_FLAGS}
    run git checkout ${BRANCH}

    # Popping stashed unstaged changes
    if ${STASHED}; then
        info "Popping unstaged changes from stash"
        run git stash pop
    fi

    exit 0
}

# Flag processing, this will only search for flags before command
for arg in $@; do
    case "$arg" in
        -h|--help)
            show_help
            shift
            ;;
        -v|--verbose)
            verbose=1
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

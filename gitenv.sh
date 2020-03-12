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

function fmt_bold()     { echo "\e[1m$@\e[0m" }
function fmt_italic()   { echo "\e[3m$@\e[0m" }
function fmt_error()    { echo $(bold "\e[31m$@\e[0m") }
function fmt_success()  { echo "\e[32m$@\e[0m" }
function fmt_msg()      { echo "\e[30m$(fmt_italic $@)\e[0m" }
function fmt_code()     { echo "'$(fmt_italic $@)'" }

# Logs message with predefined format
function info() {
    echo -e " ${VISUAL_GUIDE} ${1} $@"
}

# Logs error message with predefined format
function error() {
    echo -e " ${VISUAL_GUIDE} ${1} $@" >&2
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
            die 1 "Command $(fmt_code $@) $(fmt_error "failed with status ${status}")"
        fi
        exit 1
    fi
}

# Command that creates new branch from master as a feature branch
function create_feature() {
    if [[ ${#@} -ne 4 ]]; then
      die 1 "Expected parameters: $(fmt_code "create-feature ISSUE_NUMBER TYPE NAME")"
    fi

    ISSUE_NUMBER=$2
    TYPE=$3
    NAME=$4

    run git fetch
    run git branch ${ISSUE_NUMBER}-${TYPE}-${NAME} origin/master
    run git checkout ${ISSUE_NUMBER}-${TYPE}-${NAME}

    exit 0
}

# Creates a new branch derived from
function push_feature_for() {
    if [[ ${#@} -ne 2 ]]; then
        die 1 "Expected parameters: $(fmt_code "push-feature-for BASE_BRANCH")"
    fi

    PUSH_FLAGS=
    TARGET_BRANCH=$2
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMITS=$(git log --left-right --cherry-pick --oneline --format='%H' ${BRANCH}...master \
              | tr '\n' ' '  \
              | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')
    STASHED=false

    run git fetch

    if git diff-index --quiet HEAD --; then
        run git stash
        STASHED=true
    fi

    if ! git show-ref --verify --quiet refs/heads/${BRANCH}-${TARGET_BRANCH}; then
        echo "Branch ${BRANCH}-${TARGET_BRANCH} doesn't exists, creating new one"
        run git checkout -b ${BRANCH}-${TARGET_BRANCH}
    else
        echo "Branch ${BRANCH}-${TARGET_BRANCH} exists, moving everything there from branch ${BRANCH}"
        run git checkout ${BRANCH}-${TARGET_BRANCH}
        PUSH_FLAGS="${PUSH_FLAGS} --force"
    fi

    run git reset --hard ${TARGET_BRANCH}
    run git cherry-pick ${COMMITS}

    run git push origin ${BRANCH}-${TARGET_BRANCH}  ${PUSH_FLAGS};
    run git checkout ${BRANCH}

    if ${STASHED}; then
        run git stash pop
    fi

    exit 0
}

# Flag processing
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
    esac
done

# Processing arguments
if [[ ${#@} -lt 1 ]]; then
  die 1 "Expected parameters: COMMAND ARGS..."
fi

case "$arg" in
    create-feature)
        shift
        create_feature $@
        ;;
    push-feature-for)
        shift
        push_feature_for $@
        ;;
esac

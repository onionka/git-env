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

function run() {
    if ${verbose}; then
        echo "Executing '$@'"
    fi
    if ! $@; then
        if ${verbose}; then
            echo "Command '$@' failed with $?" >&2
        fi
        exit 1
    fi
}

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

if [[ ${#@} -lt 1 ]]; then
  echo "Expected parameters: COMMAND ARGS..." >&2
  exit 1
fi

if [[ "$1" == "create-feature" ]]; then
    if [[ ${#@} -ne 4 ]]; then
      echo "Expected parameters: create-feature ISSUE_NUMBER TYPE NAME" >&2
      exit 1
    fi

    ISSUE_NUMBER=$2
    TYPE=$3
    NAME=$4

    run git fetch
    run git branch ${ISSUE_NUMBER}-${TYPE}-${NAME} origin/master
    run git checkout ${ISSUE_NUMBER}-${TYPE}-${NAME}

    exit 0
elif [[ "$1" == "push-feature-for" ]]; then
    if [[ ${#@} -ne 2 ]]; then
      echo "Expected parameters: push-feature-for BASE_BRANCH" >&2
      exit 1
    fi

    PUSH_FLAGS=
    TARGET_BRANCH=$2
    BRANCH=$(git rev-parse --abbrev-ref HEAD)
    COMMITS=$(git log --left-right --cherry-pick --oneline --format='%H' ${BRANCH}...master \
              | tr '\n' ' '  \
              | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }')

    run git fetch

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

    run git push origin ${BRANCH}-${TARGET_BRANCH} ${PUSH_FLAGS};
    run git checkout ${BRANCH}

    exit 0
fi
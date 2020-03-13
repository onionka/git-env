# Environmental branching strategy for GIT

This small project aims to help with the glorious branching strategy 
that is representing every environment (production, staging, qa, ...) with separate
branch. Such approach is giving you a possibility for dev, QA (Quality Assurance) 
and UAT (User Acceptance Testing) teams to work independently. 

Imaging that you have a project with dev and QA team. When dev finishes their
work, the QA will test it. Every issue must be tested before releasing it
into the production. So with the standard approach (with just master branch),
when release was scheduled, the dev team have to wait until QA finishes testing.
Which means that every release we had to stop merging pull-requests, until
we released to production. With this brand new system, we don't need to wait
until QA finishes it's work, because they have their own branch and environment
on which they are working on.

This repository is providing script that makes the additional work around creating
and pushing branches much easier to do.

## Diagram representing workflow

![Workflow diagram](https://raw.githubusercontent.com/Cmiroslaf/git-env/master/diagram.png)
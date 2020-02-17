##
##          \e[4;36mDashly Backend Makefile\e[0m
##
##  Provides a lot of usefull shortcuts for building, testing, deploying and running dashly
##
##  Usage:
##
##     $ make <targets…> <variables…>
##
##  Running dependency check for all non-production programs:
##
##     $ make install
##
##=============================================================
## Install, uninstall
##
##   \e[33mTargets:\e[0m
##     \e[34minstall\e[0m - Installs git environment workflow scripts on this computer
install:
	@install --mode="+x" gitenv.sh /usr/bin/gitenv

##     \e[34muninstall\e[0m - Installs git environment workflow scripts on this computer
uninstall:
	@rm -f /usr/bin/gitenv
##
##=============================================================
## Misc and help
##
##   \e[33mVariables:\e[0m
##     \e[34mPATTERN\e[0m - AWK regex pattern for searching of the help section start
PATTERN=

##     \e[34mSEPARATOR\e[0m - AWK regex pattern for searching in help headings
SEPARATOR====+

##     \e[34mSHOW_HELP_HEADER\e[0m - Hides or shows the header of this makefile's help in search_help
SHOW_HELP_HEADER=false

##
##   \e[33mTargets:\e[0m
##     \e[34mhelp\e[0m - Shows this help
help: Makefile
	@echo -e "$$(sed -n 's/^##//p' Makefile)" | less

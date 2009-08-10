# $Id$

SHELL = sh
CONFIG = ${HOME}/cvs/WWW2sf/conf/configure
sflist = $(HOME)/data/sflist
host_file = $(HOME)/data/hosts

include $(CONFIG)

ACCESS_METHOD = ssh
WORKSPACE = $(HOME)/work/mksfs
OPTION = -s

start: mk_tasks run_tasks

mk_tasks:
	mkdir -p $(WORKSPACE) 2> /dev/null
	cat $(sflist) | awk '{print "task"NR, "sh $(scriptdir)/embed-annotation.sh $(OPTION)", $$0}' > $(WORKSPACE)/tasks

run_tasks: connect_node
	gxpc cd $(WORKSPACE)
	gxpc e pwd
	gxpc ep $(WORKSPACE)/tasks
	gxpc quit


connect_node:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME orchid
	gxpc explore --children_hard_limit 1000 -t $(host_file)
	gxpc e "hostname | grep -v $(HOSTNAME)\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname

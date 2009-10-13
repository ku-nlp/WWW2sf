# $Id$

SHELL = sh
CONFIG = ${HOME}/cvs/WWW2sf/tool/conf/configure
htmllist = $(HOME)/data/htmllist
host_file = $(HOME)/data/hosts
sflist = $(HOME)/data/sflist

DIST_HOST_OF_SF  = orchid01
DIST_DIR_OF_SF   = /data/$(USER)/tsubaki/mksfs
DIST_DIR_OF_MKSF = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF)

WORKSPACE = $(HOME)/ipsj/tsubaki/mksfs

DIST_HOST_OF_SF  = orchid01
DIST_DIR_OF_SF   = /data/skeiji/ipsj-mksf
DIST_DIR_OF_MKSF = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF)

include $(CONFIG)

NODE_PREFIX = orchid
ACCESS_METHOD = ssh
OUTPUT_DIR_PREFIX = /data/$(USER)/tsubaki/mksf/tmp
OPTION = -s -w 300

start: mk_tasks run_tasks mk_tasks4embed run_tasks4embed


mk_tasks:
	mkdir -p $(WORKSPACE) 2> /dev/null
	cat $(htmllist) | awk '{print "task"NR, "sh $(scriptdir)/make-standard-format.sh", $$0, "$(DIST_DIR_OF_MKSF)"}' > $(WORKSPACE)/tasks
	ssh $(DIST_HOST_OF_SF) rm -rf $(DIST_DIR_OF_SF) 2> /dev/null
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF)

run_tasks: connect_node1
	gxpc e rm -r $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX)
	gxpc ep $(WORKSPACE)/tasks
	gxpc quit
	mv status $(WORKSPACE)/

connect_node1:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(host_file)
	gxpc e "hostname | grep -v $(HOSTNAME)\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname | sort


mk_tasks4embed:
	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF)/"$$0}' > $(sflist)
	cat $(sflist) | awk '{print "task"NR, "sh $(scriptdir)/embed-annotation.sh $(OPTION)", $$0}' > $(WORKSPACE)/tasks4embed


run_tasks4embed: connect_node2
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX)
	gxpc e mv output output.bak 2> /dev/null
	gxpc ep $(WORKSPACE)/tasks4embed
	gxpc quit


connect_node2:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(host_file)
	gxpc e "hostname | grep -v $(HOSTNAME)\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname

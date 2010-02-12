# $Id$

# Example: make htmllist=/home/skeiji/ipsj/WWW2sf/tool/htmlfiles CONFIG=../conf/configure HOST_FILE=/home/skeiji/ipsj/WWW2sf/tool/scripts/hosts.orchids NODE_PREFIX=orchid start

SHELL = sh

# WWW2sf/tool/conf/configure の場所
CONFIG = ${HOME}/cvs/WWW2sf/tool/conf/configure

# gxp を使って並列に処理する際に利用するホスト
# 書式は以下の付録2を参照
HOST_FILE = $(HOME)/data/hosts

# tasks ファイル、status ファイルを出力する場所
LOG_OUT_DIR = $(log_out_dir)


FLAG_OF_MKHTML = 0

include $(CONFIG)

# 各ノードで作成された標準フォーマットは $(DIST_DIR_OF_MKSF) へ scp される
DIST_HOST_OF_HTML  = $(dist_host_of_html)
DIST_DIR_OF_HTML   = $(dist_dir_of_html)
DIST_HOST_OF_SF    = $(dist_host_of_sf)
DIST_DIR_OF_SF0    = $(dist_dir_of_sf0)
DIST_DIR_OF_SF1    = $(dist_dir_of_sf1)
DIST_DIR_OF_SF2    = $(dist_dir_of_sf2)
DIST_DIR_OF_MKHTML = $(DIST_HOST_OF_HTML):$(DIST_DIR_OF_HTML)
DIST_DIR_OF_MKSF0  = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF0)
DIST_DIR_OF_MKSF1  = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF1)
DIST_DIR_OF_MKSF2  = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF2)


# Makefile を実行するノードのprefix
NODE_PREFIX = orchid
ACCESS_METHOD = ssh
OUTPUT_DIR_PREFIX = $(workspace4mksfs)
OUTPUT_DIR_PREFIX_EMBED = $(workspace4embed)
OUTPUT_DIR_PREFIX_TAG = $(workspace4tag)

# 変換したい html ファイルのリスト（入力ファイル）
# 書式は以下の付録1を参照
htmllist = $(LOG_OUT_DIR)/hflist

# 素の標準フォーマットのリストを保存するファイル
sflist0 = $(LOG_OUT_DIR)/sflist0
sflist1 = $(LOG_OUT_DIR)/sflist1
sflist2 = $(LOG_OUT_DIR)/sflist2

# embed-annotation.sh のオプション
OPTION_OF_EMBED_ANNOTATION = $(option4embed_annotation)

# torque で獲得するノード数
NUM_OF_USE_NODE = 100

# mk_tasks4tag で利用
RAW_TAG_DATA = $(raw_tag_data)
TAG_DATA = $(tag_data)
OPTION_OF_EMBED_TAG = $(option_of_embed_tag)


# start で行う処理
start: mk_htmlfiles mk_tasks run_tasks mk_tasks4embed run_tasks4embed



mk_htmlfiles:
	if [ $(FLAG_OF_MKHTML) -eq 1 ]; then sh $(scriptdir)/make-htmlfile.sh $(option4mkhtmls) ; fi


mk_htmlfiles_ipsj: connect_node0
	ssh $(DIST_HOST_OF_HTML) mkdir -p $(DIST_DIR_OF_HTML) 2> /dev/null
	cat $(TXT_TGZS) | awk '{print "task"NR, "sh $(scriptdir)/ipsj-make-htmlfile.sh -C $(CONFIG) -f", $$0, "-D $(DIST_DIR_OF_MKHTML) -w 30"}' > $(LOG_OUT_DIR)/tasks4mkhtml
	gxpc ep $(LOG_OUT_DIR)/tasks4mkhtml
	gxpc quit
	mv status $(LOG_OUT_DIR)/status4mkhtml
	ssh $(DIST_HOST_OF_HTML) ls $(DIST_DIR_OF_HTML) | grep tgz | awk '{print "$(DIST_HOST_OF_HTML):$(DIST_DIR_OF_HTML)/"$$0}'> $(htmllist)


mk_tasks4tag:
	mkdir -p $(LOG_OUT_DIR) 2> /dev/null
	perl $(scriptdir)/ipsj-convert-tag-data.perl $(RAW_TAG_DATA) > $(TAG_DATA)
	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF1) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF1)/"$$0}' | grep tgz > $(sflist1)
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF2)
	ssh $(DIST_HOST_OF_SF) "rm -r $(DIST_DIR_OF_SF2) 2> /dev/null"
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF2)
	cat $(sflist1) | awk '{print "task"NR, "sh $(scriptdir)/ipsj-embed-tag-data.sh -f ", $$0, " -C $(CONFIG) $(OPTION_OF_EMBED_TAG) -D $(DIST_DIR_OF_MKSF2)"}' > $(LOG_OUT_DIR)/tasks4tag

run_tasks4tag: connect_node3
	gxpc e rm -r $(OUTPUT_DIR_PREFIX_TAG) 2> /dev/null
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX_TAG) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX_TAG)
	gxpc e mv output output.bak 2> /dev/null
	gxpc ep $(LOG_OUT_DIR)/tasks4tag
	gxpc quit
	mv status $(LOG_OUT_DIR)/status4tag

	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF2) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF2)/"$$0}' | grep tgz > $(sflist2)



# 素の標準フォーマットを作成する tasks ファイルを $(LOG_OUT_DIR) 以下に出力
mk_tasks:
	mkdir -p $(LOG_OUT_DIR) 2> /dev/null
	cat $(htmllist) | awk '{print "task"NR, "sh $(scriptdir)/make-standard-format.sh -C $(CONFIG) -f ", $$0, " -D $(DIST_DIR_OF_MKSF0)"}' > $(LOG_OUT_DIR)/tasks
	ssh $(DIST_HOST_OF_SF) rm -rf $(DIST_DIR_OF_SF0) 2> /dev/null
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF0)


# $(LOG_OUT_DIR)/tasks を gxpc ep する
# $(HOST_FILE)で指定されているノードを利用
# run_tasks: connect_node_by_torque
run_tasks: connect_node1
	gxpc e rm -r $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX)
	gxpc ep $(LOG_OUT_DIR)/tasks
	gxpc quit
	mv status $(LOG_OUT_DIR)/


# 素の標準フォーマットに解析結果を埋め込む tasks ファイル（tasks4embed）を $(LOG_OUT_DIR) 以下に出力
mk_tasks4embed:
	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF0) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF0)/"$$0}' | grep tgz > $(sflist0)
	cat $(sflist0) | awk '{print "task"NR, "sh $(scriptdir)/embed-annotation.sh -C $(CONFIG) $(OPTION_OF_EMBED_ANNOTATION)", $$0}' > $(LOG_OUT_DIR)/tasks4embed
	ssh $(DIST_HOST_OF_SF) rm -rf $(DIST_DIR_OF_SF1) 2> /dev/null
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF1)


# $(LOG_OUT_DIR)/tasks4embed を gxpc ep する
# $(HOST_FILE)で指定されているノードを利用

run_tasks4embed: connect_node2
	gxpc e rm -r $(OUTPUT_DIR_PREFIX_EMBED) 2> /dev/null
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX_EMBED) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX_EMBED)
	gxpc e mv output output.bak 2> /dev/null
	gxpc ep $(LOG_OUT_DIR)/tasks4embed
	gxpc quit
	mv status $(LOG_OUT_DIR)/status4embed

	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF1) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF1)/"$$0}' | grep tgz > $(sflist1)




# $(HOST_FILE)で指定されているノードを獲得
connect_node0:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(HOST_FILE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname

connect_node1:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(HOST_FILE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$ | grep -v $(DIST_HOST_OF_SF)"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname | sort

connect_node2:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(HOST_FILE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname

connect_node3:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(HOST_FILE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname

connect_node_by_torque:
	gxpc use torque $(NODE_PREFIX)
	gxpc explore $(NODE_PREFIX) $(NUM_OF_USE_NODE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$ | grep -v $(DIST_HOST_OF_SF)"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname | sort




############################################################################
# 付録1 $(htmllist)で指定するファイルの書式
############################################################################

# % head htmllist
# /vine4/skeiji/ipsj/tgzs/h0000.tgz
# /vine4/skeiji/ipsj/tgzs/h0001.tgz
# /vine4/skeiji/ipsj/tgzs/h0002.tgz
# /vine4/skeiji/ipsj/tgzs/h0003.tgz
# /vine4/skeiji/ipsj/tgzs/h0004.tgz
# /vine4/skeiji/ipsj/tgzs/h0005.tgz
# /vine4/skeiji/ipsj/tgzs/h0006.tgz
# /vine4/skeiji/ipsj/tgzs/h0007.tgz
# /vine4/skeiji/ipsj/tgzs/h0008.tgz
# /vine4/skeiji/ipsj/tgzs/h0009.tgz
# % tar tzf /vine4/skeiji/ipsj/tgzs/h0009.tgz | head
# h0009/
# h0009/IPSJ-MGN431125.html.gz
# h0009/KJ00003027079.html.gz
# h0009/KJ00003024979.html.gz
# h0009/IPSJ-MGN431003.html.gz
# h0009/IPSJ-MGN490614.html.gz
# h0009/KJ00001281864.html.gz
# h0009/KJ00002633236.html.gz
# h0009/KJ00003023470.html.gz
# h0009/IPSJ-MGN440507.html.gz
# 各ファイルは html ファイルを gzip 圧縮し tgz したもの


############################################################################
# 付録2 $(HOST_FILE)で指定するファイルの書式
############################################################################

# % head hosts
# orchid01 2
# orchid02 2
# orchid03 2
# orchid04 2
# orchid05 2
# orchid06 2
# orchid07 2
# orchid08 2
# orchid09 2
# orchid10 2
# ホスト名 使用するCPUコア数

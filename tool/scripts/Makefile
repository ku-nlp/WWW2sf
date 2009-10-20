# $Id$

# Example: make htmllist=/home/skeiji/ipsj/WWW2sf/tool/htmlfiles CONFIG=../conf/configure host_file=/home/skeiji/ipsj/WWW2sf/tool/scripts/hosts.orchids NODE_PREFIX=orchid start

SHELL = sh

# WWW2sf/tool/conf/configure の場所
CONFIG = ${HOME}/cvs/WWW2sf/tool/conf/configure

# 変換したい html ファイルのリスト（入力ファイル）
# 書式は以下の付録1を参照
htmllist = $(HOME)/data/htmllist

# gxp を使って並列に処理する際に利用するホスト
# 書式は以下の付録2を参照
host_file = $(HOME)/data/hosts

# tasks ファイル、status ファイルを出力する場所
WORKSPACE = $(HOME)/work/tsubaki/mksfs

# 素の標準フォーマットが出力されるノード、ディレクトリの指定
# 各ノードで作成された素の標準フォーマットは $(DIST_DIR_OF_MKSF) へ scp される
DIST_HOST_OF_SF  = orchid01
DIST_DIR_OF_SF   = /data/$(USER)/tsubaki/mksfs
DIST_DIR_OF_MKSF = $(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF)


include $(CONFIG)

# Makefile を実行するノードのprefix
NODE_PREFIX = orchid
ACCESS_METHOD = ssh
OUTPUT_DIR_PREFIX = $(workspace4mksfs)

# 素の標準フォーマットのリストを保存するファイル
sflist = $(HOME)/data/sflist

# embed-annotation.sh のオプション
OPTION_OF_EMBED_ANNOTATION = $(option4embed_annotation)

# torque で獲得するノード数
NUM_OF_USE_NODE = 100


# start で行う処理
start: mk_tasks run_tasks mk_tasks4embed run_tasks4embed




# 素の標準フォーマットを作成する tasks ファイルを $(WORKSPACE) 以下に出力
mk_tasks:
	mkdir -p $(WORKSPACE) 2> /dev/null
	cat $(htmllist) | awk '{print "task"NR, "sh $(scriptdir)/make-standard-format.sh", $$0, "$(DIST_DIR_OF_MKSF)"}' > $(WORKSPACE)/tasks
	ssh $(DIST_HOST_OF_SF) rm -rf $(DIST_DIR_OF_SF) 2> /dev/null
	ssh $(DIST_HOST_OF_SF) mkdir -p $(DIST_DIR_OF_SF)


# $(WORKSPACE)/tasks を gxpc ep する
# $(host_file)で指定されているノードを利用

# run_tasks: connect_node_by_torque
run_tasks: connect_node1
	gxpc e rm -r $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX)
	gxpc ep $(WORKSPACE)/tasks
	gxpc quit
	mv status $(WORKSPACE)/


# $(host_file)で指定されているノードを獲得
connect_node1:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(host_file)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$ | grep -v $(DIST_HOST_OF_SF)"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname | sort

connect_node_by_torque:
	gxpc use torque $(NODE_PREFIX)
	gxpc explore $(NODE_PREFIX) $(NUM_OF_USE_NODE)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$ | grep -v $(DIST_HOST_OF_SF)"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname | sort


# 素の標準フォーマットに解析結果を埋め込む tasks ファイル（tasks4embed）を $(WORKSPACE) 以下に出力
mk_tasks4embed:
	ssh $(DIST_HOST_OF_SF) ls $(DIST_DIR_OF_SF) | awk '{print "$(DIST_HOST_OF_SF):$(DIST_DIR_OF_SF)/"$$0}' > $(sflist)
	cat $(sflist) | awk '{print "task"NR, "sh $(scriptdir)/embed-annotation.sh $(OPTION_OF_EMBED_ANNOTATION)", $$0}' > $(WORKSPACE)/tasks4embed


# $(WORKSPACE)/tasks4embed を gxpc ep する
# $(host_file)で指定されているノードを利用

# run_tasks4embed:
run_tasks4embed: connect_node2
	gxpc e mkdir -p $(OUTPUT_DIR_PREFIX) 2> /dev/null
	gxpc cd $(OUTPUT_DIR_PREFIX)
	gxpc e mv output output.bak 2> /dev/null
	gxpc ep $(WORKSPACE)/tasks4embed
	gxpc quit
	mv status $(WORKSPACE)/status4embed


# $(host_file)で指定されているノードを獲得
connect_node2:
	gxpc use $(ACCESS_METHOD) $$HOSTNAME $(NODE_PREFIX)
	gxpc explore --children_hard_limit 1000 -t $(host_file)
	gxpc e "hostname | grep -v $$HOSTNAME\\$$"
	gxpc smask
	echo "*** USED HOSTS ***"
	gxpc e hostname




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
# 付録2 $(host_file)で指定するファイルの書式
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

MKFILE_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CONFIG:=$(MKFILE_DIR)/snapshot.json

TEAM:=

saas: TEAM=saas
saas: _run

terralink: TEAM=terralink
terralink: _run

yvateam: TEAM=yvateam
yvateam: _run

aksonsoft: TEAM=aksonsoft
aksonsoft: _run

saas-backup: CONFIG=$(MKFILE_DIR)/backup.json
saas-backup: TEAM=saas
saas-backup: _run

backup-test: CONFIG=$(MKFILE_DIR)/test.snapshot.json
backup-test: TEAM=backup-test
backup-test: _run

backup-test0: CONFIG=$(MKFILE_DIR)/test.backup.json
backup-test0: TEAM=backup-test
backup-test0: _run


_run:
	screen -dm bash --login -c "$(MKFILE_DIR)/dumper.sh --config $(CONFIG) -f $(TEAM) 2>&1 | tee -a $$HOME/dumper.log

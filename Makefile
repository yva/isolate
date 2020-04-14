NAME:=isolate
IMAGE:=$(NAME):latest
MKFILE_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))
OPT:=
.PHONY: dumper
.ONESHELL:
SHELL = bash

up:
	. env.load.sh --from $(MKFILE_DIR)/yva.env.json --section inf
	vagrant up --provision
	vagrant ssh

deploy:
	. env.load.sh --from $(MKFILE_DIR)/yva.env.json --section inf
	export ANSTAGS='deploy'
	vagrant up --provision && vagrant ssh

stop:
	@echo "###\n### Stopping vm\n###"
	vagrant halt

rm: stop
	@echo "###\n### Remove vm\n###"
	vagrant destroy -f
	
shell:
	@echo "###\n### Openning shell in container\n###"
	vagrant ssh

auth-test: 
	cd ansible; ansible-playbook main.yml -t test -vv

auth-deploy: OPT:='-t deploy'
auth-deploy: auth-all

auth-all:
	. env.load.sh --from $(MKFILE_DIR)/yva.env.json --section inf
	cd ansible; ansible-playbook main.yml -vv -e redis_pass=$$INF_AUTH_ISOLATE_REDIS_PASS $(OPT)

auth-dumper:
	cd ansible; ansible-playbook main.yml --tags dumper -vv

clean: stop rm

all: clean up
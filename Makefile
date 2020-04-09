NAME:=isolate
IMAGE:=$(NAME):latest
MKFILE_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.PHONY: dumper

up:
	vagrant up --provision
	vagrant ssh
stop:
	@echo "###\n### Stopping vm\n###"
	vagrant halt

rm: stop
	@echo "###\n### Remove vm\n###"
	vagrant destroy -f
	
shell:
	@echo "###\n### Openning shell in container\n###"
	vagrant ssh

test: 
	cd ansible; ansible-playbook main.yml -t test -vv

dumper: 
	cd ansible; ansible-playbook main.yml --tags dumper -vv

clean: stop rm

all: clean up
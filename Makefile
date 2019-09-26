NAME:=isolate
IMAGE:=$(NAME):latest
MKFILE_DIR:=$(dir $(abspath $(lastword $(MAKEFILE_LIST))))


up:
	vagrant up --provision

stop:
	@echo "###\n### Stopping vm\n###"
	vagrant halt

rm: stop
	@echo "###\n### Remove vm\n###"
	vagrant destroy -y
	
shell:
	@echo "###\n### Openning shell in container\n###"
	vagrant ssh

clean: stop rm

all: clean up

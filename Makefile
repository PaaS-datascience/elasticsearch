export DC_DIR=./
export DC_FILE=${DC_DIR}/docker-compose
export DC_PREFIX=latelier
export DC_NETWORK=latelier
export ES_VERSION=elasticsearch:5.6.3

# Elasticsearch configuration
# Nuber of nodes, memory, and container memory (used only for many nodes)
ES_NODES := 1
ES_MEM := 1024m

DC := 'docker-compose'
include /etc/os-release 

install-prerequisites:
ifeq ("$(wildcard /usr/bin/docker)","")
	echo install docker-ce, still to be tested
	sudo apt-get update
	sudo apt-get install \
    	apt-transport-https \
	ca-certificates \
	curl \
	software-properties-common

	curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo apt-key add -
	sudo add-apt-repository \
		"deb https://download.docker.com/linux/ubuntu \
		`lsb_release -cs` \
   		stable"
	sudo apt-get update 
	sudo apt-get install -y docker-ce
endif
	@(if (id -Gn ${USER} | grep -vc docker); then sudo usermod -aG docker ${USER} ;fi) > /dev/null
ifeq ("$(wildcard /usr/local/bin/docker-compose)","")
	@echo installing docker-compose
	@sudo curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
	@sudo chmod +x /usr/local/bin/docker-compose
endif

network-stop:
	docker network rm ${DC_NETWORK}

network: install-prerequisites
	@docker network create ${DC_NETWORK} 2> /dev/null; true

down:
	@echo docker-compose down elasticsearch
	@${DC} -f ${DC_FILE}-elasticsearch-run.yml down

vm_max:
ifeq ("$(vm_max_count)", "")
	@echo updating vm.max_map_count $(vm_max_count) to 262144
	sudo sysctl -w vm.max_map_count=262144
endif

up: network vm_max
	@echo docker-compose up elasticsearch with ${ES_NODES} nodes
	@cat ${DC_FILE}-elasticsearch.yml | sed "s/%M/${ES_MEM}/g" > ${DC_FILE}-elasticsearch-run.yml
	@sudo mkdir -p ./esdata/node1 && sudo chmod 777 ./esdata/node1 ./esdata/node1/.
	@i=$(ES_NODES); while [ $${i} -gt 1 ]; do \
		sudo mkdir -p ./esdata/node$$i && sudo chmod 777 ./esdata/node$$i/. ; \
		cat ${DC_FILE}-elasticsearch-node.yml | sed "s/%N/$$i/g;s/%VERSION/${ES_VERSION}/g;s/%M/${ES_MEM}/g" >> ${DC_FILE}-elasticsearch-run.yml; \
		i=`expr $$i - 1`; \
	done;\
	true
	${DC} -f ${DC_FILE}-elasticsearch-run.yml up -d 


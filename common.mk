.PHONY: _init validate plan apply destroy apply-full

# specify config
ORG?=onedirect
PLAN?=$(ORG)-$(ENV)-projects.tfstate
include $(ORG).backend

# use workspaces for environments
ENV?=default

_init:
	terraform init \
		-backend-config=bucket=$(BACKEND_BUCKET) \
		-backend-config=prefix=$(TIER) \
		-reconfigure -get=false
	@if ! terraform workspace list | grep -qE "^[* ][ ]$(ENV)$$"; then \
		terraform workspace new $(ENV); \
	fi
	terraform workspace select $(ENV)

get:
	@echo "The following 'terraform get' command must be run on the ANZ staff network"
	terraform get -update

$(ORG)-$(ENV).tfvars:
	@echo 'tfvars for $(ORG)-$(ENV) does not exist at $(ORG)-$(ENV).tfvars'
	@exit 1

validate: $(ORG)-$(ENV).tfvars _init
	terraform $@ \
		-var-file $(ORG)-$(ENV).tfvars

plan: $(ORG)-$(ENV).tfvars _init
	terraform $@ \
		-var-file $(ORG)-$(ENV).tfvars

apply: $(ORG)-$(ENV).tfvars _init
	terraform $@ \
		-var-file $(ORG)-$(ENV).tfvars

destroy: $(ORG)-$(ENV).tfvars _init
	terraform $@ \
		-var-file $(ORG)-$(ENV).tfvars

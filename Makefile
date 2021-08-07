
include .env

.DEFAULT_GOAL := all

all: deploy dockerimages
.PHONY: all

deploymentrole-pre:

	$(shell cat ./cicd/pipeline-deploymentrole.params | sed 's/\r//g' | sed 's/\n//g' > .params.tmp)
	envsubst < .params.tmp > .params

.PHONY: deploymentrole-pre

deploymentrole: deploymentrole-pre

	aws cloudformation deploy \
		--template-file cicd/pipeline-deployrole.yaml \
		--s3-bucket ${CLOUDFORMATION_BUCKET} \
		--s3-prefix cicd \
		--stack-name "${APP_CODE}-${ENVIRONMENT}-deployment-role" \
		--capabilities CAPABILITY_NAMED_IAM \
		--region ${AWS_REGION} \
		--profile ${AWS_PROFILE} \
		--no-fail-on-empty-changeset \
		--no-execute-changeset \
		--parameter-overrides $(shell cat .params)

.PHONY: deploymentrole

pipelineprereqs-pre:

	$(shell cat ./cicd/pipeline-prereqs.params | sed 's/\r//g' | sed 's/\n//g' > .params.tmp)
	envsubst < .params.tmp > .params

.PHONY: pipelineprereqs-pre

pipelineprereqs: pipelineprereqs-pre

	aws cloudformation deploy \
	--template-file ./cicd/pipeline-prereqs.yaml \
	--s3-bucket ${CLOUDFORMATION_BUCKET} \
	--s3-prefix cicd \
	--stack-name CodePipeline-Prereqs \
	--capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND \
	--region ${AWS_REGION} \
	--profile ${BUILD_PROFILE} \
	--no-fail-on-empty-changeset \
	--no-execute-changeset \
	--parameter-overrides $(shell cat .params)

.PHONY: pipelineprereqs

pipeline-pre:

	$(shell cat ./cicd/pipeline.params | sed 's/\r//g' | sed 's/\n//g' > .params.tmp)
	envsubst < .params.tmp > .params

.PHONY: pipeline-pre

pipeline: pipeline-pre

	aws cloudformation deploy \
		--template-file ./cicd/pipeline.yaml \
		--s3-bucket ${CLOUDFORMATION_BUCKET} \
		--s3-prefix cicd \
		--stack-name "${APP_CODE}-${ENVIRONMENT}-Pipeline" \
		--capabilities CAPABILITY_NAMED_IAM \
		--region ${AWS_REGION} \
		--profile ${BUILD_PROFILE} \
		--no-fail-on-empty-changeset \
		--no-execute-changeset \
		--parameter-overrides $(shell cat .params)


.PHONY: pipeline

build:
	sam build \
		--region ${AWS_REGION} \
		--profile ${BUILD_PROFILE} \
		${SAM_DEBUG_OPTION}

.PHONY: build

deploy-pre:

	$(shell cat ./template.params | sed 's/\r//g' | sed 's/\n//g' > .params.tmp)
	envsubst < .params.tmp > .params

.PHONY: deploy-pre

deploy: deploy-pre build
	sam package \
		--template-file .aws-sam/build/template.yaml \
		--output-template-file template-out.yaml \
		--s3-bucket ${CLOUDFORMATION_BUCKET} \
		--s3-prefix ${APP_CODE} \
		--profile ${BUILD_PROFILE} \
		--region ${AWS_REGION} \
		${SAM_DEBUG_OPTION}

	sam deploy \
		--template-file template-out.yaml \
		--s3-bucket ${CLOUDFORMATION_BUCKET} \
		--s3-prefix ${APP_CODE} \
		--stack-name "${APP_CODE}-${ENVIRONMENT}-stack" \
		--capabilities CAPABILITY_NAMED_IAM \
		--region ${AWS_REGION} \
		--profile ${AWS_PROFILE} \
		--no-execute-changeset \
		--parameter-overrides $(shell cat .params) \
		${SAM_DEBUG_OPTION}

.PHONY: deploy

runbuild: build run
.PHONY: runbuild

run:  deploypre

	sam local start-api \
		--port ${SAM_API_PORT} \
		--docker-volume-basedir ${PWD}/.aws-sam/build \
		--debug-port ${SAM_DEBUG_PORT} \
		--region ${AWS_REGION} \
		--parameter-overrides $(shell cat .params) \
		${SAM_DEBUG_OPTION}

.PHONY: run

dockerimages:

	@echo Logging into ECR
	VAR=$$(aws ecr get-login --no-include-email --region ${AWS_REGION} --profile ${AWS_PROFILE}) && bash -c "$$VAR"
	@echo Building and Packaging ReportsEnging Docker Image
	docker image build --tag ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_CODE}-${ENVIRONMENT}-report_engine:latest -f docker/ReportsEngine/Dockerfile .
	@echo Pushing ReportEngine Image to ECR
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${APP_CODE}-${ENVIRONMENT}-report_engine:latest

.PHONY: dockerimages

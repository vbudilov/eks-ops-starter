#!/bin/bash

# Definitions
AWS_REGION=us-east-1
EKS_CLUSTER_NAME=play1

# Create the cluster with Fargate enabled

cat ./cluster.yml \
     | sed "s/CLUSTER_NAME/${EKS_CLUSTER_NAME}/g" \
     | sed "s/REGION_VALUE/${AWS_REGION}/g" \
     | eksctl create cluster -f -

eksctl utils associate-iam-oidc-provider --cluster $EKS_CLUSTER_NAME --approve

STACK_NAME=eksctl-$EKS_CLUSTER_NAME-cluster
VPC_ID=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" | jq -r '[.Stacks[0].Outputs[] | {key: .OutputKey, value: .OutputValue}] | from_entries' | jq -r '.VPC')
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

aws iam create-policy --policy-name ALBIngressControllerIAMPolicy-${EKS_CLUSTER_NAME} --policy-document file://alb-ingress-iam-policy.json

kubectl apply -f rbac-role.yml

eksctl create iamserviceaccount \
       --cluster=$EKS_CLUSTER_NAME \
       --namespace=kube-system \
       --name=alb-ingress-controller \
       --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/ALBIngressControllerIAMPolicy-${EKS_CLUSTER_NAME} \
       --override-existing-serviceaccounts \
       --approve

cat ./alb-ingress-controller.yml \
     | sed "s/CLUSTER_NAME/${EKS_CLUSTER_NAME}/g" \
     | kubectl apply -f -


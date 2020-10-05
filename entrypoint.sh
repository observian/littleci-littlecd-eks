#!/bin/bash
set -e

function main() {
    validate "${INPUT_ACCESS_KEY_ID}" "access_key_id"
    validate "${INPUT_SECRET_ACCESS_KEY}" "secret_access_key"
    validate "${INPUT_REGION}" "region"
    validate "${INPUT_ACCOUNT_ID}" "account_id"
    validate "${INPUT_REPO}" "repo"
    validate "${INPUT_CLUSTER_NAME}" "eks_cluster_name"

    export AWS_ACCESS_KEY_ID=$INPUT_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY=$INPUT_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=$INPUT_REGION

    ecr get-login-password --region $INPUT_REGION  | docker login $INPUT_ACCOUNT_ID.dkr.ecr.$INPUT_REGION.amazonaws.com
    aws eks update-kubeconfig --name $INPUT_CLUSTER_NAME --region $INPUT_REGION

    local TAG=$INPUT_TAGS
    local tag_args=""
    local TAG_ARGS=$(echo "$TAG" | tr "," "\n")
    ACCOUNT_URL="$INPUT_ACCOUNT_ID.dkr.ecr.$INPUT_REGION.amazonaws.com"
    for tag in $TAG_ARGS; do
        #tag many times, but only do the build once
        tag_args="$tag_args -t $ACCOUNT_URL/$INPUT_REPO:$tag"
    done
    docker build -f $INPUT_DOCKERFILE $tag_args $INPUT_PATH
    #push up each tag
    for tag in $TAG_ARGS; do
        docker push $ACCOUNT_URL/$INPUT_REPO:$tag
    done

    export IMAGE_TAG=$INPUT_K8S_IMAGE_TAG
    envsubst < $INPUT_K8S_MANIFEST > deployment.yml
    kubectl apply -f deployment.yml
   
}

function validate() {
    if [ -z "${1}" ]; then
        >&2 echo "can't find ${2}.  Please make sure ${2} is set"
        exit 1
    fi
}


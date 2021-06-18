#!/bin/bash
set -e

function main() {
    echo "validating inputs"
    validate "${INPUT_ACCESS_KEY_ID}" "access_key_id"
    validate "${INPUT_SECRET_ACCESS_KEY}" "secret_access_key"
    validate "${INPUT_REGION}" "region"
    validate "${INPUT_ACCOUNT_ID}" "account_id"
    validate "${INPUT_REPO}" "repo"
    validate "${INPUT_EKS_CLUSTER_NAME}" "eks_cluster_name"

    echo "inputs are valid"
    echo "setting up env variables for the build"
    export AWS_ACCESS_KEY_ID=$INPUT_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY=$INPUT_SECRET_ACCESS_KEY
    export AWS_DEFAULT_REGION=$INPUT_REGION
    echo "done"

    echo "logging in to ECR and EKS"
    aws ecr get-login-password --region $INPUT_REGION  | docker login $INPUT_ACCOUNT_ID.dkr.ecr.$INPUT_REGION.amazonaws.com --username AWS --password-stdin
    aws eks update-kubeconfig --name $INPUT_EKS_CLUSTER_NAME --region $INPUT_REGION
    echo "done"
    
    local TAG=$INPUT_TAGS
    local tag_args=""
    local TAG_ARGS=$(echo "$TAG" | tr "," "\n")

    ACCOUNT_URL="$INPUT_ACCOUNT_ID.dkr.ecr.$INPUT_REGION.amazonaws.com"
    echo "setting up docker tags"
    for tag in $TAG_ARGS; do
        #tag many times, but only do the build once
        tag_args="$tag_args -t $ACCOUNT_URL/$INPUT_REPO:$tag"
    done
    echo "done"

    local BUILD=$INPUT_BUILD_ARGS
    local build_args=""
    local BUILD_ARGS=$(echo "$BUILD" | tr "," "\n")

    for buildarg in $BUILD_ARGS; do
        build_args="$build_args --build-arg $buildarg"
    done

    echo "running docker build -f $INPUT_DOCKERFILE $build_args $tag_args $INPUT_PATH"
    docker build -f $INPUT_DOCKERFILE $build_args $tag_args $INPUT_PATH
    #push up each tag
    echo "pushing up all tags"
    for tag in $TAG_ARGS; do
        docker push $ACCOUNT_URL/$INPUT_REPO:$tag
    done
    echo "done"
    export IMAGE_TAG=$INPUT_K8S_IMAGE_TAG
    echo "substituting image name"
    envsubst < $INPUT_K8S_MANIFEST > deployment.yml
    echo "done"
    echo "applying deployment to $INPUT_EKS_CLUSTER_NAME"
    kubectl apply -f deployment.yml

   
}

function validate() {
    if [ -z "${1}" ]; then
        >&2 echo "can't find ${2}.  Please make sure ${2} is set"
        exit 1
    fi
}
main

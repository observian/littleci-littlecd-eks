# ci/cd not CI/CD

### What it is
This github action is intended to get you up and running quickly so you can test out your integration environment before you've had a chance to set up unit testing and other checks to make sure your code works.

### What it is not
It is not a production-class action that will help you harden your code and protect your production environment from botched code.  If you check it in, it will deploy whether the code is good or not.

## How to use
```
name: Build and Deploy to Docker Image
on: push
jobs:
  little-ci-and-little-cd:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v2
      - name: Push image and deploy
        uses: observian/littleci-littlecd-eks@master
        with:
          access_key_id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          secret_access_key: ${{ secrets.SECRET_ACCESS_KEY }}
          account_id: ${{ secrets.AWS_ACCOUNT_ID }}
          repo: your-ecr-repo-name
          region: us-west-2
          tags: 0.1.1.${{ github.run_number }},${{ github.sha }}
          eks_cluster_name: your-eks-cluster-name
          k8s_manifest: your-k8s-manifest-template.yml
          k8s_image_tag: 0.1.1.${{ github.run_number }}
```

## Assumptions
- You have a k8s manifest with a container spec.  This can be named anything as long as the filename matches the entry in the `k8s_manifest` parameter, and it has a container spec with `repo` as the image name and the `k8s_image_tag` matches one of the tags in `tags`
- The `IAM` user whose keys you set to `access_key_id` and `secret_access_key` has all the privileges it needs to push to an ECR repo, and to deploy to your EKS cluster.

### Example manifest
```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: YOUR_DEPLOYMENT_NAME_CHANGE_ME
  namespace: spring-labs
spec:
  schedule: "*/5 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: YOUR_DEPLOYMENT_NAME_CHANGE_ME
            image: 12345678998.dkr.ecr.us-west-2.amazonaws.com/YOUR_REPO_NAME:${IMAGE_TAG}
          restartPolicy: OnFailure
```
Take note of the `${IMAGE_TAG}` referenced in this file.  This gets replaced with the value you put in `k8s_image_tag`.

### Example IAM Policy
```
{
    "Effect" : "Allow",
    "Action" : [
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImages",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetLifecyclePolicy",
        "ecr:GetLifecyclePolicyPreview",
        "ecr:GetRepositoryPolicy",
        "ecr:ListTagsForResource",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:CreateRepository",
        "ecr:PutImage",
        "ecr:PutImageTagMutability"
    ],
    "Resource" : "*"
}
```
### Example ConfigMap
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::1234567890:role/eks-node-group-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
  mapUsers: | 
    - userarn: arn:aws:iam::1234567890:user/YOUR_K8S_IAM_USER
      username: YOUR_K8S_IAM_USER
      groups:
        - system:masters
```

## Parameters
| Parameter Name | Description | Example |
| -------------- | ----------- | ------- |
| `access_key_id` | The AWS_ACCESS_KEY_ID that has permission for ECR and is mapped to the k8s cluster configmap | See AWS Docs |
| `secret_access_key` | The AWS_SECRET_ACCESS_KEY that has permission for ECR and is mapped to the k8s cluster configmap | See AWS Docs|
| `account_id` | The account ID for the AWS account you are deploying to | 123456789 |
| `repo` | the ECR image repo for the docker image you're building | `ubuntu` |
| `region` | The geographic region where the ECR repo and EKS cluster are located | `us-west-2` |
| `eks_cluster_name` | The name of the EKS cluster | `non-prod-cluster` |
| `tags` | Comma-separated list of tags you'd like to be associated with this image build | `0.1.1.2,9d5535085b6344f7808dcf450123c81a,development` |
| `build_args` | Comma-separated list of build arguments to pass to the docker build | `KEY1=VALUE1,KEY2=VALUE2,KEY3=VALUE3` |

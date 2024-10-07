# Ghost CMS Deployment on AWS ECS Using Terraform

## Introduction

This project demonstrates the deployment of the Ghost CMS web application on Amazon Web Services (AWS) using **Terraform**. It sets up the necessary infrastructure to run Ghost on AWS ECS (Elastic Container Service) with Application Load Balancer and enables automatic scaling, high availability, and resilience.

In addition, a **GitHub Actions** CI/CD pipeline is configured to:

- The pipeline tests the source code (currently a dummy step returns success) if the test job is passed the workflow continues to deploy application using terraform with the following steps.
- Automatically lint, and validate the Terraform configuration.
- On the pull requests the pipeline also adds the plan that shows the infra changes so that they can be approved before they are merged.
- Plan and apply changes to the AWS infrastructure when changes are pushed to the main branch.
Additionally, you can run this project locally for testing and development but it is not recommended for the production environment.

## Prerequisites to run locally

Before starting, ensure you have the following:

1.  **Terraform** v1.x or later
2.  **AWS CLI** with appropriate IAM user credentials configured (Administrator access or relevant permissions for provisioning ECS, ALB, VPC and other resources).
3.  **Git** installed to clone this repository.
4.  **Docker** installed (if you want to work with Ghost locally).
## Setup Instructions

### Step 1: Clone the repository

    git clone https://github.com/shaheerakr/ghost.git
	cd ghost/infra

### Step 2: Configure AWS Provider and Backend

Ensure that you have an AWS S3 bucket ready to store the Terraform state, as defined in `backend.tf`.

Modify the `terraform` block in `backend.tf` if necessary:

    terraform {
      backend "s3" {
        bucket  = "terrafrom-state-ghost"
        key     = "terraform-state.tfstate"
        encrypt = true
        region  = "us-east-1"
      }
    }

### Step 3: Setup environment variables for AWS

Ensure that you have the environment variables configured for the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, you can generate these keys from AWS and store in your environment but you need to make sure they account that they keys belong to have AWS administrator privileges such that it can create and modify services in AWS such as ECS, ALB, VPC and others.
You can also modify the `variables.tf` if you want to change the regions or any other settings.

### Step 4: Deploy the Infrastructure

To deploy the infrastructure, follow these steps:

1.  **Initialize Terraform:**
	This will initialize the modules and setup the backend
    `terraform init`

2.  **Review the changes:**
	This will give you the entire changes it will perform on your infrastructure
	`terraform plan` 

3.  **Apply the changes:**
	it will apply all the changes to your infrastructure
	`terraform apply -auto-approve` 

Once deployed, Terraform will output the DNS name of the Application Load Balancer (ALB) where the Ghost CMS will be accessible.


    Outputs:
    
    alb_dns_name = "http://<your-alb-dns-name>"

You can visit this URL in your browser to see the Ghost application running.
Here is the example of how you can see upon successful execution
![alb_dns address](https://raw.githubusercontent.com/shaheerakr/ghost/refs/heads/docs/docs/images/data.png)

To update your infra after making any changes you can re-run the step 2 and 3.

### Step 5: Cleanup Resources

To destroy the infrastructure once you're done:

	terraform destroy -auto-approve

## CI/CD Pipeline with GitHub Actions

This repository includes a GitHub Actions pipeline configured to automate testing and deployment.

### Workflow Details

The pipeline is triggered on two events:

1.  **Pull Requests** to `main` or `dev` branches.
2.  **Pushes** to the `main` or `dev` branches.

### Workflow Jobs

1.  **Test Job**: A dummy test that runs on every push or pull request event.
    
    -  This step currently outputs a "CI passed" message.
    -  Upon successful execution of this test the workflow continues and executes the terraform job which deploys the infrastructure with Ghost CMS. 
2.  **Terraform Job**:
    
    -   **Terraform Initialization**: Runs `terraform init` to initialize the backend and providers.
    -   **Terraform Lint**: Ensures the Terraform code is properly formatted using `terraform fmt -check`.
    -   **Terraform Validate**: Validates the configuration using `terraform validate`.
    -   **Terraform Plan**: Runs `terraform plan` to generate an execution plan and saves it in the runner.
    -  On pull requests events the pipeline publishes the complete plan in which it mentions all the changes to infra as a comment using GitHub actions bot so that it can be reviewed before it is merged to the `main` branch.
![Terraform report visualization in pull requests](https://raw.githubusercontent.com/shaheerakr/ghost/refs/heads/docs/docs/images/workflow.png)
     -   **Terraform Apply**: On push events through the pull requests to the `main` branch, `terraform apply` is automatically executed to apply the changes to the infrastructure.

### Secrets

Ensure the following AWS credentials and region are set up in your GitHub repository as secrets for the pipeline to work:

-   `AWS_ACCESS_KEY_ID`
-   `AWS_SECRET_ACCESS_KEY`
-   `AWS_REGION`

These secrets can be added under your repository's **Settings > Secrets and variables > Actions**.

### Branch protection

We have placed branch protection rules on the main branch so that the no one can make changes to the infra of the application without the review process through the pull requests.

 - We will have reviewers in our infra repo where developers will create a pull request to merge into main branch and execute infra changes.
 - Changes should be first tested locally by developers using development environment.
 - The reviewers can review the plan that is generated first from the github-actions bot and then approve the changes to be merged into main branch.

## AWS architecture for the infra
![Architecture diagram](https://raw.githubusercontent.com/shaheerakr/ghost/refs/heads/docs/docs/images/architecture.drawio.jpg)

The diagram provides an overview of the architecture of the entire AWS infra for this project.
This architecture ensures that the Ghost CMS is hosted in a secure, highly available, and scalable environment, with automated monitoring and continuous integration for seamless updates.
-   Users send requests to the **Application Load Balancer (ALB)**, which distributes traffic to the ECS tasks running in **Fargate** within the private subnets.
-   **NAT Gateways** in the public subnets provide internet access to the ECS tasks without exposing them directly to the internet.
-   The deployment and scaling of these resources are automated through **Terraform**, while **GitHub Actions** handles CI/CD processes, ensuring that the infrastructure is always in sync with the desired state.

#### 1. **VPC (Virtual Private Cloud)**

-   **Amazon VPC** provides a logically isolated network for deploying your AWS resources. The VPC is divided into public and private subnets across multiple availability zones to ensure high availability.
-   **Public Subnets**: These host the NAT Gateways and allow outbound internet access for resources in private subnets.
-   **Private Subnets**: These subnets host the ECS Fargate tasks running the Ghost CMS. The services are not directly accessible from the internet, enhancing security by keeping the Ghost containers private.

#### 2. **Public Subnets**

-   **NAT Gateways**: The NAT (Network Address Translation) Gateways are deployed in the public subnets. They allow resources in private subnets (like the Ghost ECS tasks) to access the internet for updates or external communication without exposing the tasks directly to the public internet.
-   **Application Load Balancer (ALB)**: The ALB sits in the public subnet and routes incoming HTTP requests to the Ghost services running in the ECS cluster. The ALB provides an internet-facing endpoint for users to access the Ghost CMS.

#### 3. **Private Subnets**

-   **ECS Fargate**: AWS Fargate is used to run Ghost containers in private subnets. Fargate allows you to run containers without needing to manage the underlying servers, making it easier to scale the service.
-   Each Fargate task (container) is deployed across multiple availability zones to ensure fault tolerance and high availability.
-   **ECS Cluster**: The ECS cluster manages the Fargate tasks. The cluster automatically scales based on traffic and the number of tasks required to handle the load.

#### 4. **Internet Gateway**

-   The **Internet Gateway** allows the Application Load Balancer in the public subnet to accept traffic from the internet. It connects the VPC to the internet, enabling inbound and outbound traffic flows.

#### 5. **CloudWatch Monitoring**

-   **Amazon CloudWatch** monitors the ECS Fargate tasks, the ALB, and other resources to ensure that the infrastructure is running smoothly.
-   Metrics such as CPU and memory usage, response times, and error rates are tracked. CloudWatch can also trigger autoscaling actions based on pre-defined conditions.

#### 6. **GitHub Actions**

-   The CI/CD pipeline is integrated using **GitHub Actions** to automate the deployment and management of the infrastructure. When code is pushed or a pull request is opened, GitHub Actions runs tests and triggers Terraform to plan and apply changes.
-   The pipeline automates tasks such as initializing Terraform, validating the configuration, generating execution plans, and applying changes to AWS resources.

#### 7. **Terraform**

-   **Terraform** is used as the infrastructure-as-code (IaC) tool to define and provision the AWS resources. It automates the creation of VPCs, subnets, security groups, ECS tasks, and load balancers.
-   Terraform manages the state of the infrastructure and ensures that the configuration is consistent and repeatable across environments.
- We use **S3** as backend for the **Terraform state** to ensure that state is always in sync across all the platforms 

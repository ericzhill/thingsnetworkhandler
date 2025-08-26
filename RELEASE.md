# Release process

This project releases a prebuilt AWS Lambda zip via GitHub Releases. Terraform then pulls that exact versioned artifact and deploys it.

Prerequisites
- Git set up with push access to the repo
- Go toolchain (to build locally if you want, but CI builds for releases)
- GitHub Actions enabled for this repository
- Terraform >= 1.5 installed
- AWS CLI v2 installed and configured for SSO with a profile named "ijack"

Release steps
1. Commit and push all code changes
   - Make sure tests pass locally if you run them: go test ./...
   - Commit your changes: git add -A && git commit -m "Your message"
   - Push to the main branch (or the branch you are releasing from).

2. Create and push a semantic version tag
   - Choose the next version (example v1.2.3) following SemVer.
   - Tag and push:
     git tag -a v1.2.3 -m "Release v1.2.3"
     git push origin v1.2.3

3. Wait for GitHub Actions to build and publish the artifact
   - Workflow: .github/workflows/build-lambda.yml
   - It triggers on tag push, builds dist/bootstrap, zips it as dist/lambda.zip, and creates a GitHub Release attaching the lambda.zip asset.
   - Verify the release exists and includes the file lambda.zip.

4. Update Terraform to point at the new version
   - Edit terraform/variables.auto.tfvars and set:
     deployed_version = "v1.2.3"
   - Ensure downlink_api_key is set appropriately in the same file.

5. Select the AWS profile used for deployment
   - Use the named SSO profile "ijack":
     export AWS_PROFILE=ijack

6. Refresh AWS credentials via SSO
   - Login with SSO so Terraform can authenticate:
     aws sso login --profile ijack

7. Deploy with Terraform
   - From the terraform directory:
     cd terraform
     terraform init -upgrade
     terraform plan
     terraform apply
   - Terraform will:
     - Download the release asset from:
       https://github.com/ericzhill/thingsnetworkhandler/releases/download/${var.deployed_version}/lambda.zip
     - Upload it into an S3 bucket it manages
     - Update the Lambda function to the new artifact and version environment variable

Notes and troubleshooting
- If the plan fails to fetch the GitHub release asset, confirm the tag exists, the GitHub Release is published, and that it contains lambda.zip.
- variables.auto.tfvars is auto-loaded by Terraform; you can also pass -var-file explicitly if you prefer.
- The DOWNLINK_API_KEY used by the Lambda comes from var.downlink_api_key in Terraform; keep this secret.
- After apply, you can find the Lambda Function URL in the AWS Console; logs are under CloudWatch Logs group /aws/lambda/<random>-thingsnetworkhandler

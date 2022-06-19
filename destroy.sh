#!/bin/sh
cd terraform
terraform destroy --auto-approve
helm delete devmysql
helm delete prodmysql
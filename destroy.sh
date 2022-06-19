#!/bin/sh
helm delete devmysql
helm delete prodmysql
terraform destroy --auto-approve
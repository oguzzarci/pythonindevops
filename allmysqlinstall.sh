#!/bin/sh
echo "Helm Repo Add"
helm repo add bitnami https://charts.bitnami.com/bitnami
echo "Helm Repo Update"
helm repo update
echo "Dev Mysql Being Installed"
helm install devmysql bitnami/mysql --set metrics.enabled=true --set namespaceOverride=dev
echo "Prod Mysql Being Installed"
helm install prodmysql bitnami/mysql --set metrics.enabled=true --set namespaceOverride=prod
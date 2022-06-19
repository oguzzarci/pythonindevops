# ```HELM İLE İLK DEPLOY```

> Başarılı bir build aldık ve mysql'lerimizi deploy ettik. Şimdi yazdığım helm chart ile dev ve prod ortamıza ilk deploy'u yapıyorum.
```sh
helm install pythonappdev ./pythonapphelm --set namespace=dev --set deployment.name=pythonappdev --set deployment.image.repository=********.dkr.ecr.eu-west-1.amazonaws.com --set deployment.image.name=pythonappregistry --set deployment.image.tag=12  --set mysqlconfig.MYSQL_PASSWORD_SECRET_NAME="devmysql" --set mysqlconfig.MYSQL_PORT_3306_TCP_ADDR="devmysql.dev.svc.cluster.local"
````

![N|Solid](./images/helmdev.png)

![N|Solid](./images/helmdev2.png)

![N|Solid](./images/helloworld.png)
<br/><br/>

```sh
helm install pythonapprod ./pythonapphelm --set namespace=prod --set deployment.name=pythonapprod --set deployment.image.repository=********.dkr.ecr.eu-west-1.amazonaws.com --set deployment.image.name=pythonappregistry --set deployment.image.tag=12  --set mysqlconfig.MYSQL_PASSWORD_SECRET_NAME="prodmysql" --set mysqlconfig.MYSQL_PORT_3306_TCP_ADDR="prodmysql.prod.svc.cluster.local"
````

<br/>


![N|Solid](./images/helmdev3.png)
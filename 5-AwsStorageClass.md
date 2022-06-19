![N|Solid](./images/k8s.png)

<br /><br />

## AWS Storage Class
> Deploy ettiğimiz uygumaların bazıları persistence dataya ihtiyaç duyabilirler. Uygulama pod'u silindiğinde yada yeniden açıldığında kalıcı datalarını kaybetmemesi için bunu kullanıyoruz. 
Örnek olarak; MySQL,Redis,MongoDB vs.

<br/><br />
Aşağıdaki yaml ile oluşturduğumuz cluster'a storageclass ekliyoruz.
```yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp2
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp2
  fsType: ext4
```
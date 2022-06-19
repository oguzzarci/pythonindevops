## ```Release Pipeline```

> Build pipelineda uygulamamızı ```BuildId``` versiyonlamıştık. Şimdi bu ```BuildId```  göre kubernetes ortamına deploy yapacağız Aşağıdaki adımları takip ederek başlayalım.

1. AzureDevOps'a kubernetes service connection girilmesi.
2. BuildId için pipeline Variable group oluşturulması.
3. [Replace Tokens](https://marketplace.visualstudio.com/items?itemName=qetza.replacetokens) extensions yüklenmesi.
4. Dev ve Prod Stage'lerinin kurulması.
5. Prod ortamı için Pre-deployment approvals adımının tanımlanması. Prod ortamına bizim onayımız olmadan çıkmayacak.

### ```AzureDevOps'a kubernetes service connection girilmesi.```
> Ansible bizim için kubernetes config dosyasını local bilgisayarımıza indiriyordu. Projemizin service connections bölümünden kubernetes'i bulalım. Next diyerek devam edelim.

![N|Solid](./images/k8ssc.png)

> admin.conf dosyamızının içeriğini aşağıdaki gibi kopyalayıp ve Service connection name vererek kaydedelim. Burada server master sunucumuzun private ip'si olacaktır. Onu putput'ta gelen master sunucumuzun public ip'si ile değiştirelim.

<br/>

### ```NOT :``` Local bilgisayarınızda bu config dosyası ile işlem yaptığınız da Certificate hatası alırsanız aşağıdaki komutu çalıştırarak bu hatayı ignore edebilirsiniz.
```sh
kubectl config set-cluster kubernetes --insecure-skip-tls-verify=true
```

<br/>

![N|Solid](./images/k8sscok.png)


![N|Solid](./images/k8sscok2.png)

### ```BuildId için pipeline Variable group oluşturulması.```
> Build ve release pipeline'ı farkı olduğu için ortak bir variable group oluştuğ BuildId'sini kullanmalarını sağlıyoruz.

![N|Solid](./images/vg.png)

| Name | Value |
| ------ | ------ |
| buildId | $(Build.BuildId) |

![N|Solid](./images/vg2.png)

### ```Replace Tokens extensions yüklenmesi.```
> AWS extension'nı yüklediğimiz gibi yüklüyoruz.

![N|Solid](./images/rp.png)

### ```Dev ve Prod Stage'lerinin kurulması```

> Proje sayfasında sol sekmede bulunan Pipelines Release kısmından Create Pipeline diyerek yeni bir pipeline oluşturuyoruz. Empty job diyerek devam ediyoruz.

![N|Solid](./images/newpipeline.png)

> Sol tarafta bulunan ```Artifacts``` hem build pipeli'nı hemde Helm chart'm repoda olduğu için kodlarımızın oldu repoyu ekliyorum.

![N|Solid](./images/newpipeline2.png)

![N|Solid](./images/newpipeline3.png)

>Oluşturduğumuz Variable Group'u ekliyoruz.

![N|Solid](./images/vb2.png)

> Hem başarılı build alındığında Release Pipeli tetiklenmesini istiyorsak aşağıdaki trigger'ı açmamız gerekiyor

![N|Solid](./images/releasetrigger.png)

> Pipeline aşağıdaki gibi;

![N|Solid](./images/release.png)
![N|Solid](./images/release2.png)
![N|Solid](./images/release2.png)


<br/><br/>
#### Yeni bir build başlattım. Build başarılı bir şekilde tamamlanırsa Release pipeline tetiklenerek dev ortamına yeni versiyonu deploy edecek.
<br/>

```Build Başarılı```
![N|Solid](./images/build.png)

<br/><br/>

```Deploy Başarılı```
![N|Solid](./images/deploy.png)

<br/><br/>

```Yeni Versiyon```
![N|Solid](./images/newversion.png)

>Prod Stage'i kurmak için Dev Stage'i clone diyerek kurabiliriz. Stage adını ve chart ismini güncellememiz gerekiyor.

![N|Solid](./images/release4.png)

![N|Solid](./images/release5.png)

<br/><br/>

### ```Prod ortamı için Pre-deployment approvals adımının tanımlanması```

![N|Solid](./images/release6.png)

![N|Solid](./images/release7.png)

Artık Prod ortamına deploy çıkarken benim onayım alınacak.

![N|Solid](./images/release8.png)

> Böyle bir durumda microsof size mail'de atıyor.

![N|Solid](./images/release9.png)

![N|Solid](./images/release10.png)
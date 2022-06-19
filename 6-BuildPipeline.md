# AZURE DEVOPS İLE CI/CD
### Gereksinimler
- Microsof Hesabı(adiniz@hotmail.com vs)

<br /><br />

## ```Build Pipeline```

> Kodlarımız github'da olacak, build alıp AWS ECR'a pushlayacağız. ```BuildId``` ile uygulamamızı versiyonlayacağız.

### Aşamalar
- AzureDevOps'da proje açılması
- Aws için service connection girilmesi
- Docker Build
- ECR Push

---

<br /><br />
```AzureDevOps'da proje açılması```
> Sol üstte New project butonuna tıkladıktan sonra proje ismini belirleyip oluşturuyoruz. 

![N|Solid](./images/createnewproject.png)

![N|Solid](./images/newproject.png)

<br /><br />

```Aws için service connection girilmesi```
> Oluşturduğumuz projeye tıkladıktan sonra sol alttan Project settings daha sonra Service connection'u seçiyoruz.

![N|Solid](./images/projectsettings.png)

![N|Solid](./images/serviceconnections.png)

![N|Solid](./images/newserviceconnection.png)

> Aşağıdaki gibi eğer AWS seçeneği görünmüyorsa AWS plugin'i yüklenmesi gerekiyor. Aşağıdaki adımları izleyerek hızlıca yükleyebilirsiniz.

1. Organization settings
2. Extensions
3. Browse marketplace
4. Search AWS

![N|Solid](./images/pg.png)

5. Plugin'e tıkladıktan sonra ```Get it free ```diyerek devam ediyoruz.

Eklemek istediğimiz organizasyonu seçecerek ``ìnstall`` diyerek devam ediyoruz.

![N|Solid](./images/ipg.png)

![N|Solid](./images/ipg.png)

<br /><br />

> Service connection ekranına tekrar geldiğinizde AWS seçeneğinin geldiğini göreceksiniz.

![N|Solid](./images/scaws.png)

Next diyerek ilerlediğimizde sizden ```Access Key ID```, ```Secret Access Key``` ve ```Service connection name``` isteyecek. Bu alanlar zorunludur.

AWS IAM üzerinden ECR'da full yetkili bir kullanıcı oluşturduktan sonra bu kullanıcının bilgilerini kullanabilirsiniz. 

![N|Solid](./images/ecrok.png)

<br /><br />

```Docker Build```
> Proje sayfasında sol sekmede bulunan Pipelines kısmından Create Pipeline diyerek yeni bir pipeline oluşturuyoruz.

![N|Solid](./images/pipeline.png)

Kodlarımız github da olacağı için aşağıdaki ```Authorize using OAuth```butonuna tıklayarak gerekli yetkileri tanımlıyoruz.

![N|Solid](./images/pipeline2.png)

![N|Solid](./images/pipeline3.png)

![N|Solid](./images/pipeline4.png)

Continue diyerek devam ediyoruz.
```Select a template``` kısmı için Empty Job diyerek devam ediyoruz.

![N|Solid](./images/pipeline5.png)

Yukarıdaki ekranı gördükten sonra soldan Docker ve Amazon ECR Push pluginlerini ekliyoruz.

![N|Solid](./images/pipeline6.png)

Ekledikten sonra aşağıdaki gibi pipeline'mızı düzenliyoruz.

![N|Solid](./images/pipeline8.png)

> Build almak için yukarıdaki Save & queue diyerek ilk build'mizi başlatıyoruz.

![N|Solid](./images/pipeline9.png)

Build başarılı bir şekilde çalıştı ve ECR'a pushladık.

![N|Solid](./images/pipeline10.png)

![N|Solid](./images/pipeline11.png)

> Kodumuza her push çıktığımızda build almasını istiyorsak aşağıdaki gibi ```trigger```'ı açmamız gerekiyor.

![N|Solid](./images/pipeline12.png)

<br /><br />

![N|Solid](./images/sonarcloud.png)
### ```Sonar Cloud Entegrasyonu```

>[SonarCloud](https://sonarcloud.io/)'ta hesap oluşturduktan sonra proje oluşturuyoruz.


>Aşağıdaki gibi sonarcloud projemizi pipeline'a nasıl ekleyeceğimizi gösteriyor. Gösterdiği komutları bir bash scripti olarak pipeline'a ekliyoruz.

![N|Solid](./images/sonar.png)

![N|Solid](./images/sonar2.png)

![N|Solid](./images/sonar3.png)
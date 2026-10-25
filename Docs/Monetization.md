# Plain gelir modeli

25 Ekim 2026 için öneri: sınırsız ücretsiz not defteri + Plain Pro.
Amaç, kullanıcı notlarını biriktirdikten sonra erişimini kesmek yerine, daha yoğun
çalışan kişilerin gelişmiş araçlar için ödeme yapmasını sağlamak.

## Seçilen paket

| Ücretsiz | Plain Pro |
| --- | --- |
| Sınırsız Markdown notları, klasörler, etiketler | Odak modu ve daktilo kaydırması |
| Arama, wiki bağlantıları, görev listeleri | Önceki 25 sürümü görüntüleme ve geri yükleme |
| iCloud eşzamanlama, widget’lar, paylaşım uzantısı | Sayfalara ayrılmış PDF dışa aktarma |
| Not kilidi, çöp kutusu | Uyumlu Apple Intelligence cihazlarında başlık, etiket ve özet yardımı |
| Markdown içe/dışa aktarma ve tüm kütüphaneyi ZIP yedekleme | Gelecekteki Pro araçları |

Pro sona erdiğinde kullanıcı tüm mevcut notlarını okumaya, değiştirmeye ve
Markdown olarak dışa aktarmaya devam eder. Sürüm kaydı ücretsiz kullanıcılar için
de tutulur; geçmiş ekranını açmak Pro gerektirir. Satın alma yalnızca kullanıcı
Pro ekranında bir planı seçip onayladığında başlar. Açılışta zorunlu ödeme ekranı yok.

## Fiyat önerisi

- Aylık: **2,99 USD/ay**.
- Yıllık: **19,99 USD/yıl**.

Bunlar `Configuration/Plain.storekit` içindeki yerel test fiyatlarıdır. Gerçek
fiyatlar App Store Connect’te tanımlanır; uygulama her zaman StoreKit’in
`displayPrice` değerini gösterir. Türkiye ve diğer ülkeler için fiyatları mağaza
bazında ayrıca incele. Uygulamaya döviz dönüşümü ya da sabit TL fiyatı yazılmadı.

Aylık seçenek düşük giriş maliyeti sunar, yıllık seçenek düzenli kullananlar için
maliyeti düşürür. İki plan aynı Pro haklarını açar ve aynı abonelik grubundadır;
Apple plan değişikliğini ve dönem sonunu yönetir. Ömür boyu plan bulunmaz.
İndirim sayacı, gösterilmeyen yenileme ücreti veya yapay deneme süresi yok.
Bu fiyatların dönüşüm sağlayacağı henüz kullanıcı verisiyle doğrulanmış değil.

Karşılaştırma: [Bear](https://bear.app/) ücretsiz temel kullanım ve Pro aboneliği
sunuyor; sayfasındaki ABD fiyatları aylık 2,99 USD ve yıllık 29,99 USD.
Plain’in mevcut, daha dar kapsamı için daha düşük bir yıllık giriş fiyatı seçildi.
Başlangıç fiyatlarını lansman sonrası dönüşüm verisiyle güncelle.

## Satışa açma

1. App Store Connect’te mevcut `com.onur6541.plain` uygulamasında ücretli uygulama
   sözleşmesini, vergi ve banka bilgilerini tamamla.
2. **Plain Pro** abonelik grubunda `com.onur6541.plain.pro.annual` ürününü bir
   yıllık otomatik yenilenen abonelik olarak oluştur.
3. Aynı abonelik grubunda `com.onur6541.plain.pro.monthly` ürününü bir aylık
   otomatik yenilenen abonelik olarak oluştur. İki ürünü aynı hizmet seviyesine
   yerleştir; ikisi de aynı hakları verir. Family Sharing şu an kapalı.
4. İngilizce ve Türkçe ad/açıklama, fiyat, satış bölgeleri ve inceleme ekran
   görüntülerini ekle. Ürün kimlikleri uygulamanın bundle identifier’ından
   üretilir; APP_NAME değişirse hem Connect ürünleri hem StoreKit test dosyası
   birlikte güncellenmeli.
5. Uygulamadaki gizlilik politikasını gerçek, herkese açık bir URL’de yayımla ve
   App Store Connect’e bu URL’yi ekle. Pro ekranı Apple’ın standart EULA’sına
   bağlantı içeriyor. Gizlilik metni reklam/analiz SDK’sı olmadığını anlatır;
   sonradan böyle bir SDK eklenirse metin ve App Privacy bilgileri güncellenmeli.
6. `Plain` şemasıyla TestFlight’a gönder. Sandbox’ta satın alma, yeniden yükleme,
   geri yükleme, abonelik süresinin bitişi ve iade akışını doğrula; ardından
   ürünleri uygulama sürümüyle birlikte App Review’a gönder.

**App Store Connect ürünleri bu kod değişikliğiyle oluşturulmuş veya satışa
çıkarılmış değildir.** Ürünler yoksa uygulama fiyat uydurmaz, ödeme düğmesi
sunmaz ve mevcut ücretsiz not defterini kullanılabilir tutar.

[Apple StoreKit 2](https://developer.apple.com/storekit/),
[geçerli haklar](https://developer.apple.com/documentation/storekit/transaction/currententitlements),
[satın alımları geri yükleme](https://developer.apple.com/documentation/storekit/appstore/sync()),
[App Review kuralları](https://developer.apple.com/app-store/review/guidelines/).

## Yerel test

```sh
xcodegen generate
xcodebuild -project Plain.xcodeproj -scheme Plain \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -project Plain.xcodeproj -scheme Plain-StoreKit \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -parallel-testing-enabled NO test
```

`Plain` olağan birim ve arayüz testlerini çalıştırır; gerçek App Store akışını
kullanır. `Plain-StoreKit`, `Configuration/Commerce.xctestplan` ile yerel satın
alma testlerini çalıştırır; Xcode’dan Run seçilirse doğrudan Pro ekranını açar.
Yerel StoreKit yapılandırması yalnızca bu ayrı geliştirme şemasında seçilidir.
Pro’nun açık olduğunu söyleyen bir UserDefaults anahtarı veya debug bayrağı yok.

## İlk müşterileri bulma

1. İlk hedef kitle: iPhone’da Markdown kullanan geliştiriciler ve günlük yazanlar.
   Mağaza mesajı: “Hesapsız Markdown not defteri. Odaklan, sürümlere dön,
   çalışmanı PDF olarak paylaş.” Yalnızca AI üzerinden konumlanma; cihaz desteği
   bütün kullanıcılarda yok.
2. İlk üç App Store ekran görüntüsü: yazım/split görünümü, sürüm geçmişinden
   kurtarma, PDF çıktısı. Özellik listesi yerine somut kullanım göster.
3. Yedi günlük TestFlight denemesinde kullanıcıların hangi Pro özelliğini
   istediğini ve fiyatı neden kabul/reddettiğini sor. İlk aşamada ayrı bir
   reklam ya da analiz SDK’sı eklemeden geri bildirim topla.
4. App Store Connect Analytics’ten mağaza sayfası → indirme → satın alma,
   abonelik yenilemeleri ve iadeleri takip et. Bunlar mağaza ölçümleridir;
   uygulama içine özel paywall olay analizi eklenmedi.
5. Önce mağaza metni ve ekran görüntülerini iyileştir. Ücretli reklamı, gerçek
   dönüşüm ve elde tutma verisi olmadan büyütme.

Gelir hesabı: 100 yıllık müşteri bu başlangıç fiyatıyla 1.999 USD/yıl brüt
satış oluşturur; Apple komisyonu, vergiler, iadeler ve müşteri edinme maliyeti
buna dahil değildir.

## Bu ortamda doğrulama sınırı

Mevcut Xcode 26.6 + iOS 26.5 (23F77) simülatöründe StoreKitTest,
`SKInternalErrorDomain Code=3` ile yapılandırmayı kaydedemedi; ürün listesi boş
kaldı ve işlem oluşturma çağrıları `notEntitled` döndürdü. Test planı ile de aynı
hata yeniden üretildi. Satın alma/iade/süre sonu testleri bu ortamda **başarılı
olarak doğrulanmış değildir**. Bu testleri çalışabilen bir StoreKit Test ortamında
ve ürünler oluşturulduktan sonra TestFlight Sandbox’ta tamamlamadan satışa çıkma.
Apple, ilgili simülatör/CLI sorununu
[bu geliştirici forumu yanıtında](https://developer.apple.com/forums/thread/826971)
belgeliyor; bu ortamın logları rapordaki belirtilerle eşleşiyor.

Yerel incelemede bulunan gizlilik ve yedekleme sorunları da ele alındı: kilitli
notlarda geçmiş/dışa aktarma/Canlı Etkinlik erişimi kimlik doğrulaması gerektirir;
Spotlight ve Kestirmeler gövdeyi açığa çıkarmaz; tüm kütüphane dışa aktarılırken
kilitli notlar için doğrulama istenir. Klasör adları aynı dosya yoluna dönüştüğünde
ZIP notların üzerine yazmaz. Otomatik çöp temizliği eski sürüm gövdelerini de siler.

Son doğrulama: Release derlemesi, 65 birim testi ve 13 arayüz testi geçti.
ZIP klasör adı çakışması
ayrı bir çalıştırmada yeniden kontrol edildi: aynı dosya adına sahip iki not da
arşivde ayrı dosyalar olarak korundu. Sekiz StoreKit entegrasyon testi derlendi;
işlem çalıştırma doğrulaması yukarıdaki ortam hatası nedeniyle tamamlanamadı.

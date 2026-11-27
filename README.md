# Ev Arkadaşım

Ev Arkadaşım, birlikte yaşayan kişilerin ortak giderleri paylaşmasını ve kimin kime ne kadar borcu olduğunu takip etmesini sağlayan bir mobil uygulamadır. Bir üye market alışverişini veya faturayı kaydeder, masrafa katılanları seçer ve uygulama payları hesaplar. Borçlu üye ödeme yaptığını bildirir; bakiye ancak alacaklı ödemeyi onaylayınca değişir.

**Ders:** Mobil Uygulama Programlama · İstanbul Beykent Üniversitesi, Bilgisayar Mühendisliği

**Proje ekibi:** Gökalp Daşdelen ve Ramazan Doğan

## Uygulamada neler var?

| Ekran | Ne yapılır? |
| --- | --- |
| **Özet** | Toplam borç ve alacak görülür. Kişi bazında bakiye incelenir ve ilgili borç satırından ödeme bildirilir. |
| **Giderler** | Giderler listelenir. Gider eklerken tutar, ödeyen kişi ve masrafa katılan üyeler seçilir. Paylar kaydetmeden önce kontrol edilir. |
| **Aylık gider tablosu** | **Giderler** sekmesinden açılır. Seçilen ayın toplam harcaması, her üyenin ödediği tutar ve giderlerden kendisine düşen pay ayrı ayrı gösterilir. |
| **Ödemeler** | Gelen ve giden bildirimlerin durumu izlenir. Alacaklı gelen bildirimi onaylayabilir veya reddedebilir. |
| **Ev ayarları** | Üye listesi görülür, görünen ad düzenlenir ve oturum kapatılır. Ev sahibi buradan 24 saat geçerli, tek kullanımlık davet kodu oluşturabilir. |

## İki hesapla sunum

Bu senaryo için yeni bir deneme evi ve aynı eve katılan iki ayrı hesap kullanın. İki cihaz gerekmez; bir cihazda **Ev ayarları → Çıkış yap** ile hesap değiştirebilirsiniz.

1. **A hesabı** ile kayıt olun ve bir ev oluşturun. **Ev ayarları** bölümünden görünen adınızı kaydedin ve bir davet kodu oluşturun.
2. **B hesabı** ile giriş yapın. **Davet koduyla katıl** seçeneğini kullanın ve görünen adınızı kaydedin.
3. **A hesabı** ile **Gider ekle**’yi açın. Gider adını **Market**, tutarı **120 TL**, ödeyen kişiyi **A**, katılımcıları **A ve B** seçin. Payların **60’ar TL** olduğunu görüp gideri kaydedin.
4. **B hesabında** Özet ekranındaki **60 TL borcu** gösterin. Borç satırından **30 TL** deneme ödemesi bildirin. Bildirim beklerken borç **60 TL** kalır.
5. **A hesabında** **Ödemeler → Ödemeyi aldım** üzerinden bildirimi onaylayın. A’nın B’den alacağı **30 TL** kalır; B’nin borcu da **30 TL** olarak güncellenir.
6. **Giderler → Aylık gider tablosu** ekranını açın. Toplam gider **120 TL**, A’nın ödediği tutar **120 TL** ve kişi başı gider payı **60 TL** olarak görünür. Borç ödemesi aylık harcama toplamını değiştirmez.

## Kurulum ve çalıştırma

Proje **Flutter 3.47.7 / Dart 3.13.5** ile geliştirildi. iOS için macOS ve Xcode, Android için Android SDK gerekir. Uygulama gerçek bir iPhone’da iki hesapla denendi; Android yapılandırması depoda bulunuyor.

Depoyu ilk kez alıyorsanız, GitHub hesabınızın depoya erişimi olduğundan emin olun:

```bash
git clone https://github.com/gokalpdasdelen02-ui/ev_arkadasim.git
cd ev_arkadasim
flutter pub get
flutter devices
flutter run
```

Depo zaten bilgisayarınızdaysa proje klasöründe `flutter pub get` ile başlayın. Birden fazla cihaz varsa `flutter devices` çıktısındaki kimliği kullanarak `flutter run -d CIHAZ_ID` komutuyla hedefi seçebilirsiniz. Fiziksel iPhone’da imzalama hatası alırsanız Xcode’da `ios/Runner.xcworkspace` dosyasını açıp **Runner → Signing & Capabilities** altında geliştirme takımınızı seçin.

Projenin mevcut Firebase bağlantı dosyaları depoda yer alır. Bu yapılandırmayla çalıştırdığınızda uygulama mevcut Firebase projesine bağlanır; sunum için ayrı bir deneme evi kullanın. Kendi Firebase projenizi bağlayacaksanız Android ve iOS yapılandırmasını kendi projenize göre oluşturmanız, Authentication’da e-posta/şifre yöntemini etkinleştirmeniz ve Cloud Firestore’a [projedeki erişim kurallarını](firestore.rules) yüklemeniz gerekir.

## Kod nerede?

Flutter arayüzü kullanıcıya ekranları gösterir. **Firebase Authentication** kayıt ve oturum açmayı yönetir. **Cloud Firestore** evleri, üyeleri, giderleri ve ödeme bildirimlerini saklar. Gider ve ödeme kayıtları değiştikçe ilgili ekranlar güncellenir.

| Dosya veya klasör | Sorumluluk |
| --- | --- |
| [lib/main.dart](lib/main.dart) ve [lib/household_gate.dart](lib/household_gate.dart) | Oturumu kontrol eder; kullanıcıyı giriş, ev oluşturma/katılma veya ana ekrana yönlendirir. |
| [lib/home_dashboard.dart](lib/home_dashboard.dart) ve [lib/app_theme.dart](lib/app_theme.dart) | Ana sekmeler, ev ayarları ve ortak görsel tema. |
| [lib/add_expense_page.dart](lib/add_expense_page.dart) | Gider formu, katılımcı seçimi ve pay önizlemesi. |
| [lib/payment_widgets.dart](lib/payment_widgets.dart) ve [lib/services/payment_service.dart](lib/services/payment_service.dart) | Ödeme bildirimi ekranı, bildirim listesi ve durum değişiklikleri. |
| [lib/services/balance_calculator.dart](lib/services/balance_calculator.dart) | Kişi bazında net borç ve alacağı hesaplar; yalnızca onaylanmış ödemeleri hesaba katar. |
| [lib/monthly_expenses_page.dart](lib/monthly_expenses_page.dart) ve [lib/services/monthly_expense_report.dart](lib/services/monthly_expense_report.dart) | Aylık görünüm ve üye bazında harcama özeti. |
| [firestore.rules](firestore.rules) | Ev verilerine erişimi üyelikle sınırlar; bekleyen bir ödeme hakkında yalnızca alacaklı karar verebilir. |

Para tutarları kodda **kuruş cinsinden tam sayı** olarak işlenir. Örneğin **100 TL** üç kişiye bölündüğünde paylar **33,34 TL + 33,33 TL + 33,33 TL** olur. Böylece payların toplamı her zaman gider tutarına eşit kalır.

## Kontroller ve kapsam

```bash
flutter analyze
flutter test
```

Testler gider kaydetmeyi, seçilen ayın doğru hesaplanmasını, ekran geçişlerini, ödeme bildirimi doğrulamasını ve borcun ancak onayla güncellenmesini kapsar. Uygulama para transferi yapmaz; ev arkadaşları arasında dışarıda yapılan ödemelerin kaydını tutar. Evden ayrılma, üye çıkarma ve gider düzenleme/silme bu sürümde yer almıyor.

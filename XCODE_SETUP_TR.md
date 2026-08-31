# Menubench'i Xcode'da imzalama

1. `Menubench.xcodeproj` dosyasını Xcode ile aç.
2. Sol üstteki proje seçicisinden **Menubench** şemasını ve **My Mac** hedefini seç.
3. Mavi **Menubench** proje simgesine, ardından **TARGETS > Menubench > Signing & Capabilities** bölümüne gir.
4. **Automatically manage signing** açık kalsın ve **Team** alanından Apple Developer hesabını seç.
5. Aynı Team seçimini **TARGETS > Menubench Fan Control** için de yap. Ana uygulama ile korumalı fan yardımcısı aynı ekip tarafından imzalanmalıdır.
6. Bundle ID hazır olarak `com.celikugurdev.menubench`. Xcode bunu ekibinde kaydedebilir. Değiştirmek istersen yalnızca Xcode alanını değiştirme; yardımcı kimlikleri ve launchd yapılandırmasını da birlikte güncellemem gerekir.
7. İlk yerel deneme için **Product > Run** kullan. Dağıtım için **Product > Archive**, ardından Organizer'da **Distribute App > Developer ID** yolunu seç.

Xcode şu an giriş yapılmış Team'i görse de bu Mac'in giriş anahtar zincirinde imza sertifikası yoksa Run/Archive başarısız olur. Bir kez **Xcode > Settings > Accounts > ARIF UGUR CELIK > Manage Certificates…** bölümünden **Apple Development** ve **Developer ID Application** sertifikalarını oluştur. Debug yapılandırması Apple Development, Release/Archive yapılandırması Developer ID Application kullanır.

Proje App Sandbox'ı özellikle kapalı, Hardened Runtime'ı açık tutar. Kamera, mikrofon ve Apple Events yetkileri `Resources/Menubench.entitlements` üzerinden eklenir; gerçek erişim izinlerini macOS yine kullanıcıdan gerektiği anda ister.

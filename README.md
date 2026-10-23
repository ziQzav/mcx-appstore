# MCX Umbrel App Store

Özel Umbrel app store — umbrelOS'ta **Settings → App Store → Add Store** ile
bu repo'nun URL'sini ekleyerek kullanılır.

## Yapı

```
umbrel-app-store.yml      # store tanımı (id + name)
ignis/
  umbrel-app.yml          # uygulama manifesti
  docker-compose.yml      # Umbrel formatında compose
  gallery/                # (opsiyonel) yerel görseller
```

## İçindeki uygulamalar

- **Ignis 0.8.18** — Obsidian'ı tarayıcıda çalıştırır (https://github.com/Nystik-gh/ignis)

## Kurulum (umbrelOS)

1. umbrelOS ana ekran → **Settings → App Store**
2. **Add store** → bu repo'nun URL'sini gir (örn. `https://gitlab.com/mcx-group/mcx-appstore`)
3. Yeni "MCX App Store" görünür → **Ignis**'i kur

## Notlar

- İmaj `nobbe/ignis:0.8.18` digest ile pinli.
- İlk açılışta Obsidian'ı resmi kaynaktan indirir, 1-2 dakika sürebilir.
- Uygulamanın kendi kimlik doğrulaması yok; umbrelOS app proxy girişi
  (Umbrel login) açık kalsın.

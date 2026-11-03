# MCX Umbrel App Store

umbrelOS için özel (community) app store. Store kimliği `mcx`, adı **MCX** olduğu için
arayüzde **"MCX App Store"** olarak görünür.

## Kurulum (umbrelOS)

1. **Settings → App Store → Add store**
2. Adres: `https://github.com/ziQzav/mcx-appstore`
3. **MCX App Store** → uygulamayı seç → **Install**

## Yapı

```
umbrel-app-store.yml     # store tanımı (id + name)
mcx-<uygulama>/
  umbrel-app.yml         # manifest: sürüm, port, açıklama, galeri
  docker-compose.yml     # Umbrel formatında compose
  Dockerfile / script    # yalnız kendi imajını üreten uygulamalarda
.github/workflows/       # ghcr.io/ziqzav/... imaj build'leri
```

umbrelOS app-data'ya yalnız `docker-compose.yml` ve `umbrel-app.yml` kopyalar.
Compose dışındaki dosyalara (seccomp profili, ek config) güvenme.

## Uygulamalar

| Uygulama | Sürüm | Port | İmaj |
|---|---|---|---|
| OpenBot | 0.52.0 | 3001 (bilgi sayfası) | `ghcr.io/nightly-labs/openbot:0.52.0` |
| CloudBeaver | 26.2.3 | 8978 | `dbeaver/cloudbeaver:26.2.3` |
| Everything | 1.1.0 | 8080 | `ghcr.io/ziqzav/mcx-everything:v1.1.0` |
| Ignis | 0.8.18 | 24675 | `nobbe/ignis:0.8.18` |
| LibreDB Studio | 1.1.0-3 | 24678 | `libredb/libredb-studio:1.1.0` |
| Duck-UI | 2.5.1-2 | 24677 | `ghcr.io/caioricciuti/duck-ui@sha256` + `caddy:2-alpine` |
| Hermes Workspace | 2.3.0-7 | 24676 | `nousresearch/hermes-agent` + `ghcr.io/outsourc-e/hermes-workspace` |
| Mercury Agent | 1.4.2-12 | 24674 | `ghcr.io/ziqzav/mcx-mercury-agent:v1.4.2` |
| DS Bot | 0.2.6 | 24679 | `ghcr.io/fei2411/ds-bot` (digest pinli) |
| HomeDock OS | 2.6.2.104 | 24680 | `bansheetech/homedock-os` (digest pinli) |
| DSH Web | 0.4.14-3 | 24681 | `ghcr.io/ziqzav/mcx-dsh-web` (smanx/deepseek-harness devtools tabanı + plugin katmanı, digest pinli) |

Tüm imajlar `tag@sha256:...` biçiminde digest ile pinlidir.

## Sürüm ve imaj kuralları

- `version`, o anki imajın upstream sürümüdür. Paketleme düzeltmeleri `-2`, `-3` soneki alır.
- Sürüm artışında üçü **birlikte** güncellenir: manifest `version`, compose imaj etiketi/digest, `releaseNotes`.
- Yalnız `latest` etiketiyle bırakma; digest ekle.
- Kimlik doğrulaması olmayan uygulamalarda açıklamaya "Require Umbrel login açık kalsın, portu dışa açma" notu yazılır.

## CI

| Workflow | Çıktı |
|---|---|
| `.github/workflows/docker.yml` | `ghcr.io/ziqzav/mcx-mercury-agent` → `latest`, `v1.4.2` |
| `.github/workflows/docker-everything.yml` | `ghcr.io/ziqzav/mcx-everything` → HeyPuter HEAD pinlenir, `latest`, `v1.0.0` |
| `.github/workflows/docker-dsh-web.yml` | `ghcr.io/ziqzav/mcx-dsh-web` → `smanx/deepseek-harness:devtools-0.2.1-rc.5` (digest pinli) + dsh-web 0.4.14, `latest`, `v0.4.14-3` |

İkisi de `workflow_dispatch` ile elle çalıştırılabilir.

## Uygulama notları

- **OpenBot:** headless sunucu, port yayınlamaz; yalnız dışarı bağlanır. İlk kurulumda uygulama terminalinde `openbot login`. Electron sandbox için `seccomp=unconfined` + `apparmor=unconfined` gerekir.
- **CloudBeaver:** ilk açılışta admin bilgilerini soran kurulum sihirbazı.
- **Ignis:** ilk açılışta Obsidian'ı resmi kaynaktan indirir (1-2 dk). Kendi girişi yok.
- **Everything:** 50 web uygulaması tek container'da; sunucu tarafı kimlik doğrulama yok.
- **LibreDB Studio:** ilk açılışta parola üretip loglara yazar; `ADMIN_PASSWORD` + `JWT_SECRET` (32+ karakter) ile sabitlenir.
- **Duck-UI:** dahili TLS (caddy) kullanır; ilk ziyarette sertifika uyarısını kabul et.
- **Hermes Workspace:** giriş parolası = uygulamanın umbrelOS parolası; LLM sağlayıcı anahtarı eklenmeden sohbet çalışmaz.
- **Mercury Agent:** kullanıcı `mercury`, parola = uygulama parolası; sağlayıcı anahtarı gerekir.
- **DSH Web:** `dsh web` + dsh-web eklenti paketi (görev panosu, SSH, git graph, kullanım, temalar). İmaj, bakımlı `smanx/deepseek-harness` devtools tabanı üzerine ince bir katman: dsh/node/pnpm/uv ve araç zinciri upstream'den gelir, bizim eklediğimiz tek şey web profiline kurulu plugin paketi. Taban imajın proxy'si dsh'ı loopback'te çalıştırıp 3080'i yayınlar ve launch token'ı otomatik kullanır → **giriş token'ı dosyası yok, adres doğrudan açılır**. Host upstream'e yeniden yazıldığı için `DSH_TRUSTED_HOST` gerekmez. Model anahtarı app Environment'taki `DEEPSEEK_API_KEY` veya web UI ayarlarından girilir.
- **HomeDock OS:** tarayıcıda masaüstü + 800+ uygulama kataloğu. Host Docker socket'ini mount eder; HomeDock'un kurduğu uygulamalar umbrelOS dışında, host'ta normal konteyner olarak çalışır ve umbrelOS yedeğine girmez. `Require Umbrel login` açık kalsın; portu internete açma. Lisans PolyForm Strict (ticari olmayan kullanım).
- **DS Bot:** DeepSeek Harness + ds-bot eklentisi, tarayıcıdan kullanılır. Giriş tek seferlik token ister; her başlangıçta `Files → Apps → DS Bot → data → login-token.txt` dosyasına yazılır (`http://umbrel.local:24679/?token=...`). Model için app Environment'a `DEEPSEEK_API_KEY` gir; farklı bir host/IP ile açacaksan `DSH_TRUSTED_HOST` listesine ekle (yoksa API 403 döner). Botlar konteyner içinde tam yetkiyle çalışır.

## Yeni uygulama ekleme

1. `mcx-<upstream-ad>/` klasörü aç, `manifestVersion: 1`.
2. `app_proxy` → `APP_HOST: <id>_<servis>_1`, `APP_PORT` iç port; manifest `port` dış port.
3. Kalıcı veriyi `${APP_DATA_DIR}/...` altına bağla.
4. İmajı digest ile pinle; kendi build'in ise workflow ekle.
5. `releaseNotes` yaz; `dependencies` boş olsa da ekle.
6. Bu README'deki tabloyu güncelle.

## Yayın öncesi kontrol

- Manifest sürümü = compose imaj etiketi = `releaseNotes` sürümü.
- Kurulumdan sonra uygulama açılıyor, giriş akışı çalışıyor, veri `${APP_DATA_DIR}` altında kalıcı.
- Güncelleme sonrası eski veri korunuyor.

---

## Lisans

Bu store tanımı ve manifestler **MIT** lisanslıdır (bkz. `LICENSE`).
Paketlenen uygulamaların kendi lisansları geçerlidir; imajlar upstream projelerine aittir.

# Flexytime Mac — Terminal Cheatsheet

Sık kullanılan terminal komutları. Tüm yollar macOS varsayılan konumlarına göre.

## Dosya Konumları

```
Config:  ~/Library/Application Support/flexytime/config/flexytime/flexytime.ini
Cache:   ~/Library/Application Support/flexytime/cache/<UserPath>/*.trc
Logs:    macOS unified logging (os_log) — subsystem: com.flexytime.macos
```

---

## Logları Canlı İzleme

**Tüm Flexytime logları:**
```bash
log stream --predicate 'subsystem == "com.flexytime.macos"' --info --debug
```

**Sadece network (API gönderimleri, TRC oluşturma/gönderme):**
```bash
log stream --predicate 'subsystem == "com.flexytime.macos" AND category == "network"' --info --debug
```

**Process adına göre alternatif:**
```bash
log stream --process Flexytime --info --debug
```

**Cache klasörünü canlı izleme (.trc üretimi/silinmesi):**
```bash
watch -n 2 'ls -la ~/Library/Application\ Support/flexytime/cache/*/'
```

**Canlı curl komutunu yakala:**

Her API çağrısı `~/Library/Logs/flexytime/curl-<timestamp>.sh` olarak diske yazılır (os_log mesaj boyutu limiti olduğundan dosya yoluyla loglanır). En son istek ayrıca `curl-latest.sh` olarak da bulunur.

Log stream yalnızca "CURL saved: <path>" satırlarını gösterir:
```bash
log stream --predicate 'subsystem == "com.flexytime.macos" AND category == "network"' --info --debug | grep --line-buffered 'CURL saved'
```

En son curl'u çalıştır:
```bash
bash ~/Library/Logs/flexytime/curl-latest.sh
```

Clipboard'a al:
```bash
cat ~/Library/Logs/flexytime/curl-latest.sh | pbcopy
```

Tüm yakalanan istekleri listele:
```bash
ls -lt ~/Library/Logs/flexytime/curl-*.sh
```

Eski curl dosyalarını temizle:
```bash
rm ~/Library/Logs/flexytime/curl-*.sh
```

---

## ServiceKey

**Göster:**
```bash
cat ~/Library/Application\ Support/flexytime/config/flexytime/flexytime.ini
```

**Sadece key'i çıkar:**
```bash
grep ServiceKey ~/Library/Application\ Support/flexytime/config/flexytime/flexytime.ini | awk -F'= ' '{print $2}'
```

**Clipboard'a kopyala:**
```bash
grep ServiceKey ~/Library/Application\ Support/flexytime/config/flexytime/flexytime.ini | awk -F'= ' '{print $2}' | tr -d '\n' | pbcopy
```

---

## UserPath

UserPath = `SHA256(Username)`, burada Username = `MachineName\loginuser`.
Cache klasör adı olarak saklanır.

**Göster (dosya sisteminden):**
```bash
ls ~/Library/Application\ Support/flexytime/cache/
```

**Yeniden hesapla (doğrulama için):**
```bash
printf '%s' "$(scutil --get ComputerName)\\$(whoami)" | shasum -a 256 | awk '{print toupper($1)}'
```

---

## CompanyId

CompanyId config'de saklanmaz — ServiceKey (GuidEncoder token) decode edilerek elde edilir.

**Mevcut ServiceKey'den hesapla:**
```bash
KEY=$(grep ServiceKey ~/Library/Application\ Support/flexytime/config/flexytime/flexytime.ini | awk -F'= ' '{print $2}') && \
python3 -c "import base64; k='$KEY'.replace('-','+').replace('_','/'); k+='='*(-len(k)%4); b=base64.b64decode(k); print('{:02X}{:02X}{:02X}{:02X}-{:02X}{:02X}-{:02X}{:02X}-{:02X}{:02X}-{:02X}{:02X}{:02X}{:02X}{:02X}{:02X}'.format(b[3],b[2],b[1],b[0],b[5],b[4],b[7],b[6],b[8],b[9],b[10],b[11],b[12],b[13],b[14],b[15]))"
```

---

## Build / Run

```bash
# Debug build
xcodebuild -project FlexyMacV2.xcodeproj -scheme FlexyMacV2 -configuration Debug build

# Clean
xcodebuild clean -project FlexyMacV2.xcodeproj -scheme FlexyMacV2

# Lint
swiftlint
```

---

## Reset / Troubleshoot

**Config'i sıfırla (app ilk açılış ekranına döner):**
```bash
rm ~/Library/Application\ Support/flexytime/config/flexytime/flexytime.ini
```

**Cache'deki tüm .trc dosyalarını sil:**
```bash
rm ~/Library/Application\ Support/flexytime/cache/*/*.trc
```

**Tüm Flexytime verisini temizle (DİKKAT):**
```bash
rm -rf ~/Library/Application\ Support/flexytime/
```

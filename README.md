# Cinnet2

Godot 4 tabanli atmosferik FPS/horror prototipi.

## Teknoloji
- Engine: Godot 4.x
- Dil: GDScript
- Ana sahne: `scenes/Main.tscn`

## Proje Yapisi
- `scenes/`: Oyun sahneleri (`Main`, `Player`, `Village`, `CrashCar`, `FuelCan`)
- `scripts/`: Oynanis, dunya uretimi ve sistem scriptleri
- `shaders/`: Ortam ve VFX shader dosyalari
- `small-price-car/`: Arac modeli ve texture varliklari

## Calistirma
1. Godot 4 ile proje klasorunu acin.
2. Ana sahne olarak `scenes/Main.tscn` secin.
3. Oyunu calistirin (`F5`).

## Kontroller
- `WASD`: Hareket
- `Shift`: Kosu
- `Ctrl`: Egilme
- `Space`: Ziplama
- `P`: Kapi etkilesimi
- `F`: Gece gorusu
- `Mouse`: Bakis
- `ESC`: Fareyi serbest birak
- `Sol Tik`: Fareyi tekrar yakala

## Kod Duzeni Prensipleri
- Scriptlerde adlandirilmis sabitler kullanin, magic number birakmayin.
- Grup/action isimlerini merkezi sabitlerden yonetin.
- Dinamik `call/has_method` yerine tipli sinif cagri tercih edin.
- Uzun kurucu fonksiyonlari kucuk helper fonksiyonlara bolun.
- Scene node isimlendirmesinde tutarli PascalCase kullanin.

## Gelistirme Akisi
1. Degisikligi kucuk ve odakli tutun.
2. Headless kontrol calistirin:
   `godot --headless --path . --quit-after 1`
3. `git status` ile degisiklikleri dogrulayin.
4. Anlamli commit mesaji ile commit + push yapin.

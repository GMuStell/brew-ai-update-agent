# Brew AI Update Agent

Brew AI Update Agent to lokalny doradca aktualizacji Homebrew dla macOS. Raz w tygodniu sprawdza nieaktualne formuły i caski, wykorzystuje GitHub Copilot CLI do przygotowania rekomendacji i zapisuje czytelny raport Markdown.

> Agent nie wykonuje automatycznie `brew upgrade`. Decyzja o instalacji aktualizacji zawsze należy do użytkownika.

## Najważniejsze funkcje

- sprawdzanie aktualizacji Homebrew;
- analiza dostępnych aktualizacji przy użyciu GitHub Copilot CLI;
- research release notes;
- cache rekomendacji ograniczający ponowne analizy;
- raport `state/latest-report.md`;
- klasyfikacja:
  - 🟢 `UPDATE` – aktualizacja rekomendowana;
  - 🟡 `REVIEW` – przed aktualizacją potrzebna jest dodatkowa kontrola;
  - 🔴 `HOLD` – aktualizację należy tymczasowo wstrzymać;
- uruchamianie przez macOS `launchd` w poniedziałek o 08:00;
- brak automatycznej instalacji pakietów.

## Jak działa agent

```text
launchd (poniedziałek 08:00)
  -> bin/brew-ai-update-agent.sh
  -> aktualizacja metadanych Homebrew
  -> odczyt brew outdated
  -> sprawdzenie cache
  -> analiza nowych lub przeterminowanych pozycji przez Copilot CLI
  -> walidacja odpowiedzi
  -> aktualizacja cache
  -> wygenerowanie state/latest-report.md
  -> zapis logów
```

## Wymagania

- macOS;
- Zsh;
- Homebrew;
- Python 3;
- Git;
- GitHub Copilot CLI skonfigurowany i uwierzytelniony;
- możliwość zapisu do katalogu projektu i `~/Library/LaunchAgents`.

Sprawdzenie narzędzi:

```zsh
command -v brew
command -v python3
command -v copilot
command -v git

brew --version
python3 --version
copilot --version
git --version
```

Polecenia tylko pokazują lokalizacje i wersje. Nie aktualizują pakietów i nie uruchamiają analizy AI.

## Struktura projektu

```text
brew-ai-update-agent/
├── .gitignore
├── README.md
├── bin/
│   └── brew-ai-update-agent.sh
├── config/
│   └── com.brew-ai-update-agent.plist
├── scripts/
│   ├── open-report.sh
│   ├── run-now.sh
│   ├── show-log.sh
│   └── status.sh
├── state/
└── archive/
```

- `bin/brew-ai-update-agent.sh` – główny skrypt agenta;
- `config/com.brew-ai-update-agent.plist` – konfiguracja LaunchAgenta;
- `scripts/open-report.sh` – otwieranie lub wyświetlanie raportu;
- `scripts/run-now.sh` – ręczne zlecenie przebiegu przez `launchd`;
- `scripts/show-log.sh` – podgląd logu aplikacyjnego;
- `scripts/status.sh` – podsumowanie stanu, harmonogramu, raportu i logów;
- `state/` – lokalny cache, raporty i logi;
- `archive/` – lokalne archiwum.

Katalogów `state/` i `archive/` nie należy dodawać do repozytorium ani udostępniać innym użytkownikom.

## Instalacja

### 1. Pobierz projekt

```zsh
mkdir -p "$HOME/Projects/tools"
cd "$HOME/Projects/tools"
git clone <REPOSITORY_URL> brew-ai-update-agent
cd brew-ai-update-agent
```

Zastąp `<REPOSITORY_URL>` właściwym adresem repozytorium.

### 2. Utwórz lokalne katalogi

```zsh
mkdir -p state/cache archive "$HOME/Library/LaunchAgents"
```

Polecenie tworzy tylko brakujące katalogi.

### 3. Ustaw prawa wykonywania

```zsh
chmod +x bin/brew-ai-update-agent.sh scripts/*.sh
```

### 4. Sprawdź składnię

```zsh
for file in bin/*.sh scripts/*.sh; do
  /bin/zsh -n "$file" || exit 1
  echo "OK: $file"
done
```

`zsh -n` sprawdza składnię bez uruchamiania skryptów, Homebrew ani Copilot CLI.

### 5. Przygotuj plist dla swojego Maca

Projektowy plik:

```text
config/com.brew-ai-update-agent.plist
```

używa neutralnego identyfikatora:

```text
com.brew-ai-update-agent
```

Jeżeli zawiera placeholder `__PROJECT_ROOT__`, utwórz lokalny plist, podstawiając fizyczną ścieżkę projektu:

```zsh
PROJECT_ROOT="$(pwd -P)"

sed "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
  config/com.brew-ai-update-agent.plist \
  > "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

`pwd -P` ustala bezwzględną ścieżkę. `sed` tworzy lokalną kopię plista odpowiednią dla bieżącego użytkownika.

Sprawdź konfigurację:

```zsh
plutil -lint config/com.brew-ai-update-agent.plist
plutil -lint "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

Oba polecenia powinny zakończyć się wynikiem `OK`.

### 6. Załaduj LaunchAgenta

```zsh
launchctl bootstrap "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

Polecenie rejestruje usługę w sesji bieżącego użytkownika. Nie uruchamia `brew upgrade`.

Jeżeli usługa jest już załadowana, najpierw ją wyładuj:

```zsh
launchctl bootout "gui/$(id -u)/com.brew-ai-update-agent"
```

`bootout` może przerwać aktywny przebieg, dlatego wcześniej sprawdź status.

## Pierwszy test

### Sprawdź status

```zsh
./scripts/status.sh
```

Oczekiwane informacje:

- `LaunchAgent: LOADED`;
- aktywny skrypt zgodny z `bin/brew-ai-update-agent.sh`;
- harmonogram `Monday (Weekday 1) at 08:00`.

### Uruchom prawdziwy przebieg

```zsh
./scripts/run-now.sh --follow
```

Komenda:

- zleca uruchomienie przez `launchd`;
- może odświeżyć metadane Homebrew;
- może wykorzystać kredyty GitHub Copilot;
- nie wykonuje celowo `brew upgrade`;
- pokazuje log na żywo.

`Ctrl+C` zatrzymuje tylko podgląd logu, nie agenta.

### Sprawdź wynik

```zsh
./scripts/status.sh
./scripts/open-report.sh
```

Raport powinien powstać jako:

```text
state/latest-report.md
```

## Helpery

Helpery same znajdują katalog projektu, więc można je uruchamiać z dowolnego katalogu.

### `status.sh`

```zsh
./scripts/status.sh
```

Pokazuje stan usługi, harmonogram, aktywny skrypt, raport i ostatni rezultat.

Pełna definicja `launchctl`:

```zsh
./scripts/status.sh --raw
```

### `run-now.sh`

```zsh
./scripts/run-now.sh
```

Zleca jeden przebieg przez `launchd` i wraca do terminala.

```zsh
./scripts/run-now.sh --follow
```

Zleca przebieg i przechodzi do podglądu logu. Jeżeli agent już działa, helper nie uruchamia drugiej instancji.

### `show-log.sh`

Ostatnie 40 linii i śledzenie nowych wpisów:

```zsh
./scripts/show-log.sh
```

Ostatnie 100 linii bez śledzenia:

```zsh
./scripts/show-log.sh --no-follow --lines 100
```

### `open-report.sh`

Otwórz raport:

```zsh
./scripts/open-report.sh
```

Wyświetl raport w terminalu:

```zsh
./scripts/open-report.sh --print
```

Wyświetl ścieżkę:

```zsh
./scripts/open-report.sh --path
```

## Interpretacja raportu

### 🟢 UPDATE

Aktualizacja jest rekomendowana, ale użytkownik nadal powinien sprawdzić wpływ na swoje projekty.

### 🟡 REVIEW

Przed aktualizacją należy sprawdzić kompatybilność, release notes albo wpływ na lokalny toolchain.

### 🔴 HOLD

Istnieje konkretny powód, aby tymczasowo wstrzymać aktualizację.

Klasyfikacja AI jest rekomendacją, nie gwarancją. Dla krytycznych narzędzi zawsze sprawdzaj oficjalne release notes i wykonuj właściwe testy.

## Cache i wykorzystanie Copilot CLI

Agent zapisuje analizy zmian wersji w `state/cache/`. Ta sama świeża analiza może zostać użyta ponownie. Nowa zmiana wersji, brak cache lub przeterminowany cache powodują ponowną analizę.

Pierwszy przebieg z pustym cache może skierować do AI wszystkie wykryte aktualizacje. Liczba pozycji w raporcie nie jest tym samym co liczba analiz wykonanych w danym przebiegu.

Nie udostępniaj cudzego cache. Każdy użytkownik powinien rozpocząć z własnym lokalnym stanem.

## Harmonogram

Domyślna konfiguracja:

```text
Weekday = 1
Hour = 8
Minute = 0
```

Oznacza poniedziałek o 08:00. LaunchAgent działa w sesji zalogowanego użytkownika.

## Aktualizacja konfiguracji

Po zmianie plista przeładuj usługę:

```zsh
./scripts/status.sh

launchctl bootout "gui/$(id -u)/com.brew-ai-update-agent"

PROJECT_ROOT="$(pwd -P)"
sed "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
  config/com.brew-ai-update-agent.plist \
  > "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"

plutil -lint "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"

launchctl bootstrap "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"

./scripts/status.sh
```

## Diagnostyka

### Usługa nie jest załadowana

```zsh
./scripts/status.sh
plutil -lint "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

### Agent nie tworzy raportu

```zsh
./scripts/status.sh
./scripts/show-log.sh --no-follow --lines 100
tail -n 100 state/launchd.stderr.log
tail -n 100 state/launchd.stdout.log
```

### `copilot` lub `brew` działa w terminalu, ale nie przez `launchd`

```zsh
command -v copilot
command -v brew
command -v python3
```

`launchd` ma ograniczone środowisko i może nie dziedziczyć pełnego `PATH` z terminala. Porównaj wyniki z konfiguracją używaną przez główny skrypt.

### Kontrola znaków terminalowych w raporcie

```zsh
python3 - <<'PY'
from pathlib import Path

report = Path("state/latest-report.md")
text = report.read_text(encoding="utf-8")

print("ESC:", text.count("\x1b"))
print("BEL:", text.count("\x07"))
print("Entries:", sum(line.startswith("### ") for line in text.splitlines()))
PY
```

Oczekiwane wartości `ESC` i `BEL` to `0`.

## Bezpieczeństwo

Agent nie powinien wykonywać `brew upgrade`. Użytkownik sam decyduje o instalacji, na przykład:

```zsh
brew upgrade gh
```

To polecenie zmienia system i może aktualizować zależności. Przed wykonaniem sprawdź raport oraz oficjalne informacje o wydaniu.

Prompt AI może zawierać nazwy pakietów, wersje i opis toolchainu. Nie dodawaj do niego tokenów, haseł, danych klientów, poufnego kodu ani prywatnych adresów repozytoriów.

Przed użyciem na komputerze służbowym upewnij się, że GitHub Copilot CLI jest zgodny z zasadami organizacji.

## Przygotowanie projektu do udostępnienia

Do repozytorium powinny trafić:

```text
README.md
.gitignore
bin/
config/
scripts/
```

Nie publikuj:

```text
state/
archive/
.env
.env.*
*.log
.DS_Store
```

Przed commitem:

```zsh
grep -RIn \
  --exclude-dir='.git' \
  --exclude-dir='state' \
  --exclude-dir='archive' \
  -E '/Users/[^/]+/' . || true

for file in bin/*.sh scripts/*.sh; do
  /bin/zsh -n "$file" || exit 1
  echo "OK: $file"
done

plutil -lint config/com.brew-ai-update-agent.plist
git status --short
git diff --cached
```

Nie używaj bezrefleksyjnie `git add .`, jeżeli w katalogu znajdują się logi, lokalny cache, historyczne kopie lub odpowiedzi AI.

## Wyłączenie i odinstalowanie

Sprawdź, czy agent nie pracuje:

```zsh
./scripts/status.sh
```

Wyładuj usługę:

```zsh
launchctl bootout "gui/$(id -u)/com.brew-ai-update-agent"
```

Usuń aktywny plist:

```zsh
rm "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

`rm` usuwa tylko zainstalowaną konfigurację. Nie usuwa projektu, raportów ani cache.

## Pomoc

Każdy helper obsługuje `--help`:

```zsh
./scripts/open-report.sh --help
./scripts/run-now.sh --help
./scripts/show-log.sh --help
./scripts/status.sh --help
```

# Brew AI Update Agent

Automatyczny doradca aktualizacji Homebrew dla developerskiego Maca.

> Agent sprawdza dostepne aktualizacje, przygotowuje rekomendacje AI i zapisuje raport. Nie wykonuje automatycznie `brew upgrade`. Decyzja o instalacji nalezy do uzytkownika.

## Status dokumentacji

Dokument opisuje projekt rozwijany lokalnie i jego potwierdzona konfiguracje po konsolidacji katalogow. Aktywny skrypt znajduje sie w `bin/`, dane w `state/`, a konfiguracja w `config/`.

**Wazne przed udostepnieniem:** ostatnia migracja i skrypty pomocnicze nie zostaly w calosci przejrzane podczas przygotowywania tego README. Nie zakladamy, ze istnieje gotowy, przenosny instalator dla drugiego komputera. Ponizej znajduje sie jawna procedura instalacji recznej. Przed publikacja nalezy przetestowac ja na drugim koncie lub Macu.

Dokument nie jest potwierdzeniem bezpieczenstwa ani poprawnosci wszystkich rekomendacji modelu.

## Spis tresci

1. [Cel i zakres](#cel-i-zakres)
2. [Wymagania](#wymagania)
3. [Architektura](#architektura)
4. [Struktura katalogow](#struktura-katalogow)
5. [Instalacja na drugim Macu](#instalacja-na-drugim-macu)
6. [Codzienna obsluga](#codzienna-obsluga)
7. [Cache i koszty AI](#cache-i-koszty-ai)
8. [Format raportu](#format-raportu)
9. [Harmonogram](#harmonogram)
10. [Bezpieczenstwo i ograniczenia](#bezpieczenstwo-i-ograniczenia)
11. [Diagnostyka](#diagnostyka)
12. [Udostepnianie projektu](#udostepnianie-projektu)
13. [Wylaczenie i odinstalowanie](#wylaczenie-i-odinstalowanie)
14. [Slownik i zrodla](#slownik-i-zrodla)

## Cel i zakres

Na developerskim komputerze aktualizacja JDK, Pythona, Node, Terraform lub CLI moze wplynac na projekty. Sama lista `brew outdated` nie wyjasnia znaczenia zmiany. Agent laczy liste wersji z analiza AI i kontekstem toolchainu.

Projekt ma:

- sprawdzac aktualizacje raz w tygodniu;
- pokazywac wszystkie nadal oczekujace aktualizacje;
- analizowac nowe przypadki i okresowo odswiezac stare oceny;
- rozdzielac fakty z release notes od ogolnych srodkow ostroznosci;
- podawac korzysci, ryzyka i kontrole przed/po instalacji;
- ograniczac powtarzanie tych samych zapytan AI;
- pozostawiac instalowanie aktualizacji czlowiekowi.

Nie jest to skaner podatnosci, system zarzadzania poprawkami ani gwarancja kompatybilnosci. Tygodniowy raport nie zastepuje pilnych komunikatow bezpieczenstwa ani firmowego zarzadzania urzadzeniami.

## Wymagania

- macOS z sesja uzytkownika i `launchd`;
- Homebrew dostepny jako `brew`;
- Python 3 dostepny jako `python3`;
- GitHub Copilot CLI dostepny jako `copilot`;
- uwierzytelnione konto z dostepem do CLI i mozliwoscia wykonywania analiz;
- dostep do internetu dla Homebrew, Copilota i researchu;
- prawo zapisu w katalogu projektu i `~/Library/LaunchAgents`.

VS Code jest opcjonalny. Raport mozna czytac w dowolnym edytorze Markdown.

Sprawdzenie narzedzi:

```bash
command -v brew
command -v python3
command -v copilot
brew --version
python3 --version
copilot --version
```

Komendy pokazuja lokalizacje i wersje programow. Nie aktualizuja pakietow i nie wysylaja promptu AI.

Jesli Copilot CLI nie jest zainstalowany, aktualna dokumentacja instalacji znajduje sie w sekcji zrodel. Instalacja przez Homebrew:

```bash
brew install --cask copilot-cli
```

`install` instaluje wskazany cask i moze pobrac wymagane komponenty. To zmiana w systemie, nie kontrola tylko do odczytu. Nie instaluj drugiej kopii, jezeli `command -v copilot` juz wskazuje dzialajacy program.

Logowanie:

```bash
copilot login
```

Uruchamia uwierzytelnienie i moze zapisac dane sesji CLI. Kazdy wspolpracownik loguje sie na wlasne konto zgodnie z zasadami organizacji. Nie kopiuj cudzych tokenow ani katalogu `~/.copilot`.

Test nieinteraktywny:

```bash
copilot -p "Reply exactly: BREW_AGENT_OK" -s
```

`-p` wykonuje jeden prompt i konczy sesje. `-s` ogranicza output do odpowiedzi. Test korzysta z AI i moze zuzyc kredyty oraz zapisac lokalne logi/sesje CLI. Oczekiwana odpowiedz: `BREW_AGENT_OK`.

## Architektura

```text
launchd: poniedzialek 08:00
  -> /bin/zsh bin/brew-ai-update-agent.sh
  -> brew update
  -> brew outdated: formulae + casks
  -> oczyszczenie danych
  -> klucz SHA-256 dla kazdej linii aktualizacji
  -> sprawdzenie cache
       -> swiezy cache: wykorzystaj ocene
       -> brak/stary cache: Copilot CLI + research
  -> walidacja JSON i zapis ocen
  -> generator Markdown
  -> state/latest-report.md
  -> powiadomienie macOS
```

### Podzial odpowiedzialnosci

| Element | Zadanie |
|---|---|
| launchd | Uruchomienie procesu wedlug harmonogramu |
| zsh | Koordynowanie etapow i wywolywanie programow |
| Homebrew | Informacje o zainstalowanych i dostepnych wersjach |
| Python | Czyszczenie, JSON, cache, sortowanie i raport |
| Copilot CLI | Analiza nowych/starych ocen i research |
| osascript | Wyswietlenie powiadomienia macOS |
| Uzytkownik | Weryfikacja rekomendacji i decyzja o instalacji |

### Co robi Homebrew

```bash
brew update
brew outdated --formula --verbose
brew outdated --cask --greedy --verbose
```

- `update` odswieza Homebrew i informacje o pakietach; moze aktualizowac wewnetrzne komponenty Homebrew, ale nie jest zbiorczym `brew upgrade` aplikacji.
- `outdated` wyszukuje nieaktualne pakiety.
- `--formula` wybiera formulae, np. biblioteki i narzedzia CLI.
- `--cask` wybiera caski, np. aplikacje macOS.
- `--verbose` pokazuje wersje.
- `--greedy` uwzglednia takze caski normalnie pomijane, np. z wlasnymi aktualizacjami.

Agent nie obejmuje automatycznie wszystkiego z App Store, wszystkich rozszerzen VS Code ani zaleznosci projektow npm/pip/sbt.

## Struktura katalogow

```text
~/Projects/tools/brew-ai-update-agent/
  README.md
  bin/
    brew-ai-update-agent.sh
  config/
    com.brew-ai-update-agent.plist
  state/
    cache/
    latest-report.md
    agent.log
    launchd.stdout.log
    launchd.stderr.log
    outdated-raw.txt
    outdated.txt
    pending.txt
    prompt.txt
    ai-output.json
  archive/
    backups/
```

Dodatkowo moga pozostawac historyczne skrypty migracyjne. Nie sa wymaganym etapem nowej instalacji.

Poza projektem pozostaje aktywna konfiguracja:

```text
~/Library/LaunchAgents/com.brew-ai-update-agent.plist
```

Kopia w `config/` jest plikiem projektu; kopia w `LaunchAgents` jest konfiguracja wdrozona. Zmiana pierwszej nie aktualizuje automatycznie drugiej.

### Pliki stanu

- `outdated-raw.txt`: surowy output Homebrew.
- `outdated.txt`: oczyszczona lista aktualizacji.
- `pending.txt`: klucze i przypadki wymagajace analizy AI.
- `prompt.txt`: ostatni prompt przekazany do modelu.
- `ai-output.json`: ostatnia odpowiedz AI, przydatna do odzyskiwania i diagnostyki.
- `cache/*.json`: osobne oceny konkretnych kombinacji wersji.
- `latest-report.md`: najnowszy raport, nie archiwum wszystkich raportow.
- `agent.log`: dopisywana historia przebiegow; moze zawierac stare bledy.
- `launchd.*.log`: output i bledy na poziomie uruchamiania procesu.

## Instalacja na drugim Macu

### 1. Pobierz kod, nie cudzy stan

Umiesc aktualny skrypt `bin/brew-ai-update-agent.sh` i konfiguracje `config/*.plist` w:

```text
~/Projects/tools/brew-ai-update-agent
```

Nie uruchamiaj historycznych patchy v2.1-v2.4 ani migracji v2.5 jako instalatora nowego komputera. Te skrypty zakladaja istnienie poprzedniej instalacji i jej danych.

### 2. Przygotuj katalogi

```bash
mkdir -p "$HOME/Projects/tools/brew-ai-update-agent/state/cache" \
         "$HOME/Library/LaunchAgents"
```

`mkdir -p` tworzy brakujace katalogi nadrzedne i nie zglasza bledu, jesli juz istnieja. Nie usuwa istniejacych danych.

### 3. Dostosuj sciezki w skrypcie

Otworz `bin/brew-ai-update-agent.sh` w edytorze. W lokalnej instalacji potwierdzono bezwzgledna sciezke `STATE_DIR`. Na innym komputerze trzeba ja zmienic. Zalecana przenosna postac:

```bash
STATE_DIR="$HOME/Projects/tools/brew-ai-update-agent/state"
```

Nie pozostawiaj sciezki `/Users/...` nalezacej do autora. Sprawdz tez PATH oraz lokalizacje `brew`, `copilot` i `python3`. Skrypt uruchamiany przez launchd nie musi miec tego samego srodowiska co interaktywny terminal.

### 4. Dostosuj kontekst promptu

W skrypcie znajdz prompt i dostosuj opis toolchainu do swojego komputera. Przykladowy kontekst autora obejmuje Java 17/Scala/Metals/sbt, Databricks Bundles, Terraform/TFLint, Node/pnpm, Docker i pyenv/pipx.

Nie zakladaj, ze kazdy wspolpracownik uzywa tych samych narzedzi. Zmiana kontekstu nie uniewaznia automatycznie starego cache; na nowym komputerze zacznij od pustego `state/cache`.

### 5. Dostosuj konfiguracje launchd

W `config/com.brew-ai-update-agent.plist` sprawdz:

- `ProgramArguments`: `/bin/zsh` oraz pelna sciezka do skryptu w `bin/`;
- `StandardOutPath`: pelna sciezka do `state/launchd.stdout.log`;
- `StandardErrorPath`: pelna sciezka do `state/launchd.stderr.log`;
- `Label`: `com.brew-ai-update-agent`;
- `StartCalendarInterval`: Weekday 1, Hour 8, Minute 0.

W wartosciach plist wpisz rzeczywiste pelne sciezki. Nie zakladaj, ze launchd rozwinie `$HOME` albo `~` jak powloka.

Etykieta moze pozostac taka sama u roznych uzytkownikow. Jesli ja zmienisz, musisz zmienic tez nazwe pliku i wszystkie komendy `launchctl` w tej dokumentacji.

### 6. Sprawdz skladnie

```bash
zsh -n "$HOME/Projects/tools/brew-ai-update-agent/bin/brew-ai-update-agent.sh"
plutil -lint "$HOME/Projects/tools/brew-ai-update-agent/config/com.brew-ai-update-agent.plist"
```

`zsh -n` sprawdza skladnie bez wykonania skryptu. `plutil -lint` sprawdza skladnie plist. Te kontrole nie testuja logowania, internetu, poprawnosci analizy AI ani wszystkich sciezek wykonania.

### 7. Wdroz konfiguracje

```bash
cp "$HOME/Projects/tools/brew-ai-update-agent/config/com.brew-ai-update-agent.plist" \
   "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
launchctl bootstrap "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

`cp` tworzy lub nadpisuje wdrozona konfiguracje. `bootstrap` rejestruje agenta w sesji biezacego uzytkownika. `$(id -u)` podstawia UID; nie kopiuj UID autora. Nie wykonuj bootstrap ponownie dla juz zaladowanej uslugi bez jej wczesniejszego wyladowania.

### 8. Sprawdz i uruchom test

```bash
launchctl print "gui/$(id -u)/com.brew-ai-update-agent"
launchctl kickstart "gui/$(id -u)/com.brew-ai-update-agent"
```

`print` tylko wyswietla stan. `kickstart` uruchamia prawdziwy przebieg: aktualizuje metadane Homebrew, zapisuje stan i moze wywolac AI. Pierwszy przebieg z pustym cache moze analizowac wszystkie pozycje.

Sprawdz log i raport zgodnie z kolejnym rozdzialem. Dopiero poprawny test z launchd potwierdza dzialanie w srodowisku harmonogramu.

## Codzienna obsluga

### Otworz raport

```bash
open -t "$HOME/Projects/tools/brew-ai-update-agent/state/latest-report.md"
```

`open -t` otwiera plik w domyslnym edytorze tekstowym. Nie wykonuje rekomendowanych komend.

Jesli masz polecenie `code`:

```bash
code "$HOME/Projects/tools/brew-ai-update-agent/state/latest-report.md"
```

Otwiera raport w VS Code. Podglad Markdown: Cmd+Shift+V.

### Obserwuj log

```bash
tail -f "$HOME/Projects/tools/brew-ai-update-agent/state/agent.log"
```

`tail -f` pokazuje koncowke i dopisywane linie. Ctrl+C konczy tylko podglad, nie agenta.

### Uruchom teraz

```bash
launchctl kickstart "gui/$(id -u)/com.brew-ai-update-agent"
```

Uruchamia zarejestrowana usluge. Nie uruchamiaj rownolegle skryptu bezposrednio: oba przebiegi moglyby nadpisywac te same pliki.

Wariant `kickstart -k` przerywa dzialajaca instancje i uruchamia nowa. Uzywaj go tylko przy swiadomym restarcie, nie jako sposobu sprawdzania postepu. Przerwanie moze zmarnowac rozpoczeta analize AI.

### Zaktualizuj wybrany pakiet samodzielnie

```bash
brew upgrade gh
```

Aktualizuje wskazana formule i moze aktualizowac wymagane zaleznosci. To nie jest operacja tylko do odczytu ani gwarancja zmiany jednego pliku.

```bash
brew upgrade --cask visual-studio-code
```

Aktualizuje wskazany cask. Zamknij aplikacje i zapisz prace przed aktualizacja. Przejrzyj raport i informacje producenta.

Agent sam nie wykonuje tych polecen. Po aktualizacji pozycja zniknie z kolejnego raportu, jesli Homebrew przestanie ja zwracac jako outdated.

## Cache i koszty AI

Klucz jest wyliczany z oczyszczonej linii, np.:

```text
openjdk@17 (17.0.20.1) < 17.0.21.0.2
  -> SHA-256
  -> state/cache/<hash>.json
```

Hash to identyfikator, nie szyfrowanie. Zawartosc cache pozostaje zwyklym JSON-em.

| Sytuacja | Zachowanie |
|---|---|
| Ta sama linia, swiezy cache | Ponownie pokazuje rekomendacje bez nowej analizy tej pozycji |
| Zmieniona wersja zainstalowana lub docelowa | Nowy klucz, nowa analiza |
| Brak cache | Analiza AI |
| Cache starszy niz prog 28 dni | Ponowna analiza |
| Pakiet nie jest juz outdated | Nie trafia do aktualnego raportu |

Wiek jest sprawdzany na podstawie czasu modyfikacji pliku. Kopiowanie lub migracja cache moze odswiezyc ten czas i przesunac kolejna analize. Nie jest to niezalezny znacznik czasu ostatniego researchu.

Jeden przebieg moze wyslac wiele nowych pozycji w jednym promptcie. Nie oznacza to stalego kosztu ani jednego kredytu. Research, model i dlugosc odpowiedzi moga wplywac na zuzycie.

Nie ustawiono limitu `--max-ai-credits`, zgodnie z priorytetem kompletnej analizy. Nie gwarantuje to zakonczenia: pozostaja limity konta, sieci i bledy modelu.

## Format raportu

- UPDATE: rekomendacja aktualizacji, nie gwarancja bezpieczenstwa.
- REVIEW: potrzebne sprawdzenie zgodnosci lub dodatkowych informacji.
- HOLD: konkretny potwierdzony powod do wstrzymania.

Kazdy wpis zawiera nazwe, wersje, klasyfikacje, ustalenia, powod, korzysci, ryzyka oraz kontrole przed i po.

`Pending updates` to liczba pozycji raportu. `AI analyses refreshed` to liczba pozycji skierowanych do AI w danym przebiegu, nie liczba wszystkich ocen ani rachunek za kredyty.

**Wazne:** aktualny schemat nie wymusza adresow zrodel przy `confirmed_findings`. Samo slowo "verified" w odpowiedzi modelu nie dowodzi weryfikacji. Przy waznych decyzjach sprawdz oficjalne release notes. Zalecanym kolejnym ulepszeniem jest pole `sources` z URL-ami i data analizy.

Kontrole w raporcie sa propozycjami, nie automatycznie wykonywanymi testami. Nie kopiuj calego pola do terminala bez przegladania: moze laczyc komendy z opisem lub placeholderem. Testy projektowe moga wykonywac kod, pobierac zaleznosci i wymagac dostepu do sieci. `pnpm install` zmienia lokalne zaleznosci; `tflint --init` pobiera pluginy; polecenia planowania moga korzystac z infrastruktury i uwierzytelnienia. Nie sa uniwersalnie operacjami bez skutkow ubocznych.

## Harmonogram

Potwierdzona konfiguracja:

```text
Weekday = 1
Hour = 8
Minute = 0
```

**Poniedzialek to 1. Niedziela to 0 lub 7. Nie zmieniaj poniedzialku na 2.** Wczesniejsza sugestia takiej zmiany byla bledna.

Agent jest LaunchAgentem uzytkownika, nie usluga systemowa. Nie zakladaj wykonania, gdy komputer jest wylaczony lub uzytkownik wylogowany. Dokumentacja StartCalendarInterval opisuje laczenie pominietych zdarzen podczas uspienia w jedno wykonanie po obudzeniu. Nie jest to gwarancja wykonania o 08:00 na niedostepnym komputerze.

Zmiana harmonogramu:

1. Zmien `config/*.plist` w edytorze.
2. Sprawdz `plutil -lint`.
3. Wyladuj aktywna usluge.
4. Skopiuj konfiguracje do `~/Library/LaunchAgents`.
5. Zarejestruj ja ponownie.
6. Sprawdz `launchctl print`.

Komendy przeladowania:

```bash
launchctl bootout "gui/$(id -u)/com.brew-ai-update-agent"
cp "$HOME/Projects/tools/brew-ai-update-agent/config/com.brew-ai-update-agent.plist" \
   "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
launchctl bootstrap "gui/$(id -u)" \
  "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist"
```

`bootout` wyladowuje usluge i moze przerwac aktywny przebieg. Wykonuj przeladowanie, gdy agent nie pracuje.

## Bezpieczenstwo i ograniczenia

### Granica odpowiedzialnosci

Skrypt lokalny wykonuje Homebrew, zapisuje pliki i wyswietla powiadomienia. Model ma analizowac, nie administrowac komputerem.

W znanej wersji wywolanie CLI laczy szerokie zezwolenia na narzedzia/URL-e z zakazami `shell` i `write`. GitHub opisuje pierwszenstwo regul deny. **Nie jest to sandbox ani dowod, ze kazdy mozliwy efekt uboczny jest zablokowany**, zwlaszcza przy dodatkowych MCP/pluginach. Przed udostepnieniem przejrzyj faktyczne wywolanie, konfiguracje CLI i ogranicz narzedzia do potrzebnego researchu. Nie dodawaj `--yolo`.

### Dane wysylane do AI

Prompt zawiera liste pakietow, wersje i opis toolchainu. To informacje o srodowisku pracy. Research moze wysylac nazwy i wersje do zewnetrznych serwisow. Przed uzyciem sluzbowym sprawdz zasady organizacji. Nie dodawaj sekretow, tokenow, danych klientow ani poufnego kodu do promptu.

### Ograniczenia implementacji wymagajace uwagi

- Poprawny JSON nie gwarantuje poprawnych faktow.
- Sprawdzenie liczby obiektow i pol nie dowodzi poprawnego przypisania oceny do pakietu. Historyczny parser kojarzyl odpowiedzi po kolejnosci.
- Nie nalezy traktowac fallbacku migracji jako dowodu zachowania tozsamosci wszystkich ocen.
- Historyczne `outdated ... || true` moze ukrywac blad odczytu jako pusty wynik. Komunikat "up to date" wymaga ostroznosci, jesli Homebrew mial problemy.
- Zapis wielu plikow cache nie jest pelna transakcja. Blad w polowie walidacji moze pozostawic czesc nowych wpisow.
- Wczesniejsze wersje nie sprawdzaly konsekwentnie kodu zakonczenia generatora raportu. Sam komunikat `Complete` nie zastapi kontroli raportu.
- Nie ma potwierdzonej rotacji logow, automatycznego sprzatania starego cache ani kompletnego mechanizmu ponawiania.
- Nie zweryfikowano jeszcze calego finalnego kodu po migracji na drugim Macu.

To lista jawnych ograniczen, nie twierdzenie, ze kazdy przebieg jest bledny. Przed szerszym wdrozeniem zalecane sa testy, atomowe zapisy, walidacja tozsamosci i jawne kody bledow.

## Diagnostyka

### Agent nie wystartowal

```bash
launchctl print "gui/$(id -u)/com.brew-ai-update-agent"
```

Tylko odczyt. Sprawdz `arguments`, `state`, `runs`, `last exit code` i `event triggers`. `not running` jest normalne miedzy przebiegami. `runs = 0` po ponownym bootstrap nie oznacza, ze agent nigdy nie dzialal wczesniej.

### Ostatnie logi

```bash
tail -n 80 "$HOME/Projects/tools/brew-ai-update-agent/state/agent.log"
tail -n 80 "$HOME/Projects/tools/brew-ai-update-agent/state/launchd.stderr.log"
```

`-n 80` pokazuje ostatnich 80 linii, bez zmian w plikach. Stary blad przed najnowszym `Start` nie musi dotyczyc biezacego przebiegu.

### JSONDecodeError

Zachowaj `ai-output.json`, `pending.txt` i log przed kolejnym uruchomieniem. Nie wywoluj od razu AI ponownie: odpowiedz moze nadawac sie do odzyskania. Parser `strict=False` toleruje literalne znaki kontrolne w stringach, ale nie naprawia dowolnie uszkodzonego lub ucietego JSON-u.

### Liczba wpisow i znaki kontrolne

```bash
python3 - <<'PY'
from pathlib import Path
p = Path.home() / 'Projects/tools/brew-ai-update-agent/state/latest-report.md'
s = p.read_text()
print('ESC:', s.count('\x1b'))
print('BEL:', s.count('\x07'))
print('Entries:', sum(line.startswith('### ') for line in s.splitlines()))
PY
```

Czyta raport i liczy naglowki oraz znaki sterujace. Niczego nie zapisuje i nie wywoluje AI. Zero ESC/BEL jest pozadane. Liczba naglowkow nie dowodzi unikalnosci ani prawdziwosci rekomendacji.

### Brak powiadomienia

Najpierw sprawdz raport i log. Brak bannera nie dowodzi bledu analizy. Sprawdz ustawienia powiadomien macOS i tryb skupienia. Powiadomienie nie jest jedynym kanalem wyniku.

## Udostepnianie projektu

Udostepniaj kod i dokumentacje, nie osobisty stan dzialania.

Zalecany zakres:

- `README.md`;
- aktualny `bin/brew-ai-update-agent.sh`;
- zanonimizowana konfiguracja w `config/`;
- ewentualne testy i rzeczywiscie istniejace skrypty instalacyjne.

Nie udostepniaj domyslnie:

- `state/` i `archive/`;
- tokenow i konfiguracji uwierzytelnienia;
- prywatnych logow, promptow i odpowiedzi AI;
- konfiguracji z cudza sciezka `/Users/...`;
- historycznych patchy jako rzekomego instalatora.

Proponowana zawartosc `.gitignore`:

```gitignore
state/
archive/
.DS_Store
*.log
.env
.env.*
```

To propozycja do zapisania w repozytorium, nie automatycznie zastosowana konfiguracja. `.gitignore` nie usuwa plikow juz sledzonych przez Git.

Kontrola przed commitem:

```bash
git status --short
git diff --cached
```

Obie komendy tylko pokazuja stan/zmiany. Przejrzyj kazdy plik przed publikacja. Nie zakladaj, ze `git add .` jest bezpieczne bez kontroli zawartosci.

Przed przekazaniem wspolpracownikom:

- [ ] Sciezki sa przenosne albo opisane jako wymagajace konfiguracji.
- [ ] Repozytorium nie zawiera stanu, tokenow ani osobistych backupow.
- [ ] Kontekst toolchainu mozna dostosowac.
- [ ] Uprawnienia CLI zostaly przejrzane.
- [ ] Pierwszy przebieg z pustym cache dziala na drugim Macu.
- [ ] Drugi przebieg wykorzystuje cache.
- [ ] Zmieniona wersja uruchamia nowa analize.
- [ ] Raport zawiera jedna ocene na kazda aktualizacje.
- [ ] Poniedzialek pozostaje Weekday 1.
- [ ] Zasady organizacji dopuszczaja taki sposob uzycia AI.

## Wylaczenie i odinstalowanie

Wylaczenie harmonogramu:

```bash
launchctl bootout "gui/$(id -u)/com.brew-ai-update-agent"
```

Wyladowuje usluge, moze przerwac przebieg, nie usuwa raportow ani cache.

Aby nie ladowala sie ponownie przy kolejnej sesji, po wyladowaniu przenies aktywna konfiguracje poza `LaunchAgents`:

```bash
mv "$HOME/Library/LaunchAgents/com.brew-ai-update-agent.plist" \
   "$HOME/Projects/tools/brew-ai-update-agent/config/com.brew-ai-update-agent.disabled.plist"
```

Przenosi jeden plik; nie usuwa kodu ani danych. Nie wykonuj, jesli plik docelowy juz istnieje i chcesz go zachowac.

Nie trzeba odinstalowywac Homebrew, Pythona ani Copilota, aby usunac agenta. Katalog projektu usuwaj dopiero po zachowaniu potrzebnych raportow i sprawdzeniu sciezki. README celowo nie podaje zbiorczego `rm -rf`.

## Slownik i zrodla

- **CLI**: program obslugiwany z terminala.
- **LaunchAgent**: zadanie macOS powiazane z sesja uzytkownika.
- **plist**: plik konfiguracji property list.
- **cache**: zapis poprzedniej oceny do ponownego wykorzystania.
- **SHA-256**: funkcja tworzaca stabilny identyfikator z danych.
- **JSON**: struktura danych dla parsera.
- **Markdown**: tekstowy format raportu.
- **OSC/ANSI/BEL**: znaki/sekwencje terminalowe, nie czesc nazwy pakietu.
- **research**: wyszukiwanie informacji; nie gwarancja poprawnosci modelu.

Zrodla dokumentacji narzedzi:

- [Homebrew: dokumentacja polecen](https://docs.brew.sh/Manpage)
- [GitHub: instalacja Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli)
- [GitHub: zezwalanie i blokowanie narzedzi](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools)
- [GitHub: konfiguracja Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/configure-copilot-cli)
- [StartCalendarInterval: opis i numeracja dni](https://alvinalexander.com/mac-os-x/launchd-plist-examples-startinterval-startcalendarinterval/)

Lokalne podreczniki macOS, tylko odczyt:

```bash
man launchd.plist
man launchctl
```

`man` otwiera dokumentacje dostepna na konkretnym Macu; `q` zamyka podglad. Przy roznicach wersji sprawdz lokalna dokumentacje oraz `copilot --help`.

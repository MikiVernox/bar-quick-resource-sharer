# Quick Ally Resource Sharer (Beyond All Reason Widget)

Un widget per **Beyond All Reason (BAR)** che monitora lo stato economico degli alleati e mostra avvisi discreti con pulsanti a singolo click per inviare energia o metallo a chi ne ha disperato bisogno.

---

## ⚡ Perché questo Widget?

Nei match multigiocatore di BAR (come gli 8v8 su *Supreme Strait*, *Glitter*, *All Metal*):
- I giocatori in prima linea spesso subiscono stalli devastanti di energia o metallo per riparare torrette o ricaricare scudi.
- I giocatori eco/tech accumulano riserve enormi in overflow che finiscono per andare sprecate.
- Aprire il menu diplomazia, selezionare il giocatore, spostare la barra e inviare le risorse è un'operazione lenta che toglie concentrazione dal combattimento.

**Questo widget semplifica il teamplay:**
- Rileva in automatico quando un alleato sta stallando.
- Verifica che tu abbia riserve adeguate prima di proporre la donazione (per non mandare te stesso in stallo).
- Mostra una notifica discreta con pulsante di invio rapido (`+500 E` o `+200 M`) e un pulsante per silenziare l'avviso (`x`).

---

## 🛡️ Fair Play & Conformità alle Regole di BAR

Questo widget è **100% conforme al Codice di Condotta di Beyond All Reason**:
1. **Nessun botting o macro automatica:** L'invio delle risorse **non avviene mai da solo**. Richiede sempre il click cosciente del giocatore.
2. **Nessun dato nascosto:** Legge solo i dati delle risorse del proprio `AllyTeam`, che sono già visibili a tutti i compagni di squadra nell'interfaccia predefinita.
3. **Open Source & Pubblico:** Il codice sorgente è aperto e liberamente condivisibile nel canale Discord `#widgets`.

---

## 📥 Installazione

1. Trova la cartella di installazione di Beyond All Reason sul tuo computer:
   - **Linux:** `~/.config/Beyond-All-Reason/data/LuaUI/Widgets/` oppure `~/.local/share/beyond-all-reason/data/LuaUI/Widgets/`
   - **Windows:** `%LocalAppData%\Programs\Beyond-All-Reason\data\LuaUI\Widgets\`
2. Copia il file [`gui_quick_resource_sharer.lua`](LuaUI/Widgets/gui_quick_resource_sharer.lua) all'interno della cartella `LuaUI/Widgets/`.
3. In gioco:
   - Premi `F11` (o apri il menu dei widget) e cerca **"Quick Ally Resource Sharer"** per attivarlo.
   - Oppure apri la chat di gioco e digita `/luaui reload` per ricaricare i widget senza riavviare.

---

## ⚙️ Configurazione

Puoi personalizzare i parametri all'inizio del file `gui_quick_resource_sharer.lua` nella tabella `CONFIG`:

```lua
local CONFIG = {
  checkIntervalFrames   = 30,    -- Controllo circa ogni secondo
  energyShareAmount     = 500,   -- Quantità di energia inviata per click
  metalShareAmount      = 200,   -- Quantità di metallo inviata per click
  
  -- Soglie per identificare lo stallo alleato
  energyStallThreshold  = 100,
  metalStallThreshold   = 50,
  
  -- Riserve minime personali prima di proporre donazioni
  myMinEnergyReserve    = 1000,
  myMinMetalReserve     = 400,
  
  -- Posizione a schermo (da sinistra / dal basso)
  posX                  = 50,
  posY                  = 500,
  
  -- Durata silenziamento con tasto 'x' (secondi)
  snoozeDurationSec     = 45,
}
```

---

## 📜 Licenza

Rilasciato sotto licenza [GNU General Public License v2.0 or later](LICENSE).

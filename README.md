# 🛡️ VPS Deterministic Rescue Kit

Questo repository contiene un set di strumenti Ansible e script Bash per eseguire una diagnostica non distruttiva su un VPS bloccato o irraggiungibile, utilizzando un ambiente di ripristino (Live ISO). L'intero workflow è progettato per essere **deterministico, sicuro** e **automatico**.

## 🚀 Descrizione

Il VPS Deterministic Rescue Kit è una soluzione robusta e affidabile per diagnosticare e potenzialmente risolvere problemi comuni che rendono un Virtual Private Server inaccessibile. Sfruttando un ambiente Live ISO, Ansible automatizza l'acquisizione di informazioni vitali senza alterare lo stato del sistema bloccato, permettendo un'analisi approfondita e mirata e guidando l'utente attraverso un processo strutturato di recupero.

## ✨ Funzionalità Chiave

*   **Diagnostica Non Distruttiva**: Acquisisce log e dati sullo stato del disco montando la partizione del VPS bloccato in modalità sola lettura, senza modificarne lo stato.
*   **Workflow Deterministico e Sicuro**: Un processo ben definito che minimizza il rischio di errori e garantisce la sicurezza dei dati sensibili e del sistema.
*   **Bootstrap Automatico**: Script Bash per configurare rapidamente un utente temporaneo con accesso SSH e `sudo NOPASSWD` sulla Live ISO.
*   **Acquisizione Log Automatica**: Scarica automaticamente i log cruciali (es. `journalctl`, `df -h`, `syslog`) dal VPS bloccato al Control Node.
*   **Estrazione Log Locale**: I log scaricati vengono automaticamente estratti in una directory locale sul Control Node per una facile analisi.
*   **Fasi Chiare di Recupero**: Il processo è suddiviso in fasi distinte: Preparazione & Bootstrap (manuale/shell), Diagnostica (Ansible), Analisi e Risoluzione (Ansible).

## 🛠️ Tecnologie Usate

*   **Ansible**: Per l'automazione della diagnostica e la gestione delle configurazioni sul VPS remoto.
*   **Bash**: Per lo script di bootstrap iniziale sulla Live ISO.
*   **SSH**: Per la connessione sicura tra il Control Node e la Live ISO.
*   **Linux Live ISO**: L'ambiente di ripristino avviato sul VPS.
*   **`chroot`**: Utilizzato per eseguire comandi all'interno del sistema operativo del VPS bloccato.
*   **`curl`**: Per scaricare ed eseguire lo script di bootstrap.
*   **`tar`**: Per archiviare i log prima del download al Control Node.

## 📂 Struttura del Progetto

```
vps-deterministic-rescue/
├── .env                       # Contiene dati sensibili (IP del VPS, password temporanea) e viene ignorato da Git.
├── .gitignore                 # Definisce le regole per i file e le directory da escludere dal controllo versione.
├── ansible.cfg                # Configurazione globale per Ansible.
├── README.md                  # La documentazione estesa e dettagliata del progetto.
├── ansible/                   # Directory che contiene i playbook e l'inventario Ansible.
│   ├── hosts_remote.ini       # Un inventario minimale con variabili di base per l'host temporaneo.
│   └── diagnose_playbook.yml  # Il playbook principale per la fase di diagnostica automatica.
└── scripts/                   # Contiene script Bash ausiliari.
    └── bootstrap.sh           # Script per configurare l'ambiente iniziale sulla Live ISO.
```

## ⚙️ Configurazione e Utilizzo

Questa sezione descrive come configurare e utilizzare il kit di salvataggio. Assicurati di avere **Ansible** e un ambiente Linux/macOS configurato per SSH sul tuo Control Node (la macchina da cui eseguirai i comandi). Sebbene Node.js non sia direttamente utilizzato da questo progetto, è una precondizione comune per molti ambienti di sviluppo.

### 1. Preparazione Iniziale (Control Node)

1.  **Crea il file `.env`**:
    Nella directory radice del progetto, crea un file chiamato `.env` per memorizzare le credenziali sensibili. **Questo file è già configurato per essere ignorato da Git (`.gitignore`)**, garantendo che le tue credenziali non vengano committate.

    ```bash
    # .env

    # IP del VPS che esegue la Live ISO (es. 192.168.1.100)
    REMOTE_IP=INSERISCI_QUI_IL_TUO_IP

    # Password temporanea per 'tempuser' (deve corrispondere a quella usata nel bootstrap)
    BOOTSTRAP_PASSWORD=INSERISCI_QUI_LA_PASSWORD_SICURA
    ```

2.  **Configurazione di Git e Ansible**:
    Verifica che i file `ansible.cfg` e `ansible/hosts_remote.ini` siano presenti e contengano le configurazioni fornite nel repository.

### 2. Fase 0: Bootstrap Remoto (VPS - Console KVM/VNC)

Questa fase viene eseguita direttamente sulla console KVM/VNC del tuo VPS, poiché il server è in uno stato irraggiungibile via rete.

1.  **Avvia la Live ISO**: Avvia il tuo VPS in modalità di ripristino utilizzando una Live ISO (es. SystemRescue, Ubuntu Minimal, la Rescue Mode fornita dal tuo provider).
2.  **Ottieni l'IP Pubblico**: Una volta avviata la Live ISO, ottieni il suo indirizzo IP pubblico (es. con il comando `ip a`). Questo sarà il tuo `REMOTE_IP`.
3.  **Esegui il Bootstrap**: Copia e incolla il seguente comando nella console della Live ISO. Sostituisci `<URL_BOOTSTRAP_SH>` con l'URL grezzo del file `scripts/bootstrap.sh` del tuo repository GitHub e `INSERISCI_QUI_LA_PASSWORD_SICURA` con la password che userai per l'utente temporaneo `tempuser` (deve essere la stessa che hai inserito nel tuo file `.env`).

    ```bash
    BOOTSTRAP_PASSWORD=INSERISCI_QUI_LA_PASSWORD_SICURA curl -sL <URL_BOOTSTRAP_SH> | bash
    ```
    Questo script configurerà un utente `tempuser` con la password fornita, abiliterà `sudo NOPASSWD` per tale utente, installerà `openssh-server` e altri strumenti necessari per Ansible, e preparerà un mount point per il sistema operativo del VPS bloccato.

### 3. Fase 1: Diagnostica Automatica (Control Node)

Dopo aver completato la Fase 0, puoi procedere con la diagnostica automatica dal tuo Control Node.

```bash

# 1. Caricamento robusto delle variabili dal file .env
while IFS='=' read -r key value; do
    key=$(echo "$key" | xargs)
    if [[ ! -z "$key" && "$key" != \#* ]]; then
        export "$key"="$value"
    fi
done < .env

# 2. Esecuzione Ansible
# Passiamo l'IP e tutte le credenziali, PIÙ la partizione target
ansible-playbook -i "$REMOTE_IP," ansible/diagnose_playbook.yml \
    -e "ansible_user=tempuser" \
    -e "ansible_password=$BOOTSTRAP_PASSWORD" \
    -e "ansible_become_pass=$BOOTSTRAP_PASSWORD" \
    -e "target_partition=/dev/vda1" # <-- DA AGGIORNARE!!!
    
```

### Risultato della Diagnostica

Al termine dell'esecuzione, il playbook avrà completato i seguenti passaggi:
*   Montaggio in sola lettura della partizione target del VPS sulla Live ISO.
*   Acquisizione di log cruciali (`journalctl`, `df -h`, copia di `syslog`) dal sistema operativo bloccato.
*   Creazione di un archivio `.tar.gz` contenente tutti i log sul VPS remoto.
*   Download automatico dell'archivio sul tuo Control Node.
*   **Estrazione automatica** dei log in una directory locale per una facile analisi.

I log saranno disponibili sul tuo Control Node in una directory con data e ora, ad esempio: `./vps_diagnostics_output/logs_20251102-160000/`.

## 🚀 Deployment

Questo progetto non è un'applicazione web o un servizio che richiede deployment su piattaforme di hosting statico come Netlify, Vercel o GitHub Pages. Si tratta invece di un toolkit di diagnostica per server, progettato per essere eseguito localmente dal tuo "Control Node" (la tua macchina di sviluppo/amministrazione) e interagire con un VPS remoto tramite SSH e Ansible.

Il concetto di "deployment" in questo contesto si traduce nella preparazione e nell'esecuzione del Control Node:
1.  **Preparazione del Control Node**: Assicurati che Ansible e SSH siano installati e configurati correttamente sul tuo sistema locale per poter comunicare con il VPS.
2.  **Gestione delle Credenziali**: Le variabili d'ambiente cruciali come `REMOTE_IP` e `BOOTSTRAP_PASSWORD` vengono gestite in modo sicuro tramite il file `.env` e caricate nella shell prima dell'esecuzione dei playbook, come dettagliato nella sezione "Configurazione e Utilizzo". Questo approccio è analogo alla configurazione di variabili d'ambiente in un ambiente CI/CD, ma applicato al tuo ambiente di esecuzione locale.
3.  **Accesso alla Live ISO**: La fase più critica è avviare il VPS con una Live ISO e configurare SSH manualmente, come dettagliato nella "Fase 0: Bootstrap Remoto".

## 🤝 Contributo

Il VPS Deterministic Rescue Kit è un progetto open-source e accoglie con entusiasmo contributi di ogni tipo! Il tuo aiuto è fondamentale per migliorare questo strumento e renderlo utile per una comunità più ampia.

Se desideri contribuire:

*   **Segnalare Bug**: Se trovi un bug, per favore apri un'Issue su GitHub, descrivendo il problema in dettaglio e i passaggi per riprodurlo.
*   **Suggerire Funzionalità**: Hai un'idea per una nuova funzionalità o un miglioramento? Apri un'Issue per discuterne.
*   **Inviare Pull Request**: Se hai sviluppato una funzionalità o corretto un bug, sentiti libero di aprire una Pull Request. Assicurati che il tuo codice segua le convenzioni del progetto e che i test (se presenti) passino.

Ogni contributo è apprezzato!

## 📄 Licenza

Questo progetto è rilasciato sotto la Licenza MIT.

```
[MIT License Text Placeholder]
```

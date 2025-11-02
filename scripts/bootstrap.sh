#!/bin/bash
#
# vps-deterministic-rescue: Bootstrap per Live ISO SSH/Ansible
# Versione: 3.0
# Descrizione: Configura SSH e un utente temporaneo su una Live ISO.
#
# Esecuzione: BOOTSTRAP_PASSWORD=LaTuaPass curl -sL <URL_BOOTSTRAP> | bash
#

set -e

# --- 1. VERIFICA SICUREZZA ---
if [[ $EUID -ne 0 ]]; then
   echo "ERRORE: Questo script deve essere eseguito come root." >&2
   exit 1
fi

if [ -z "${BOOTSTRAP_PASSWORD}" ]; then
    echo "ERRORE: La variabile d'ambiente BOOTSTRAP_PASSWORD non è stata trovata." >&2
    echo "Esempio: BOOTSTRAP_PASSWORD=LaTuaPass curl ... | bash" >&2
    exit 1
fi

echo "--- Avvio Bootstrap per Ansible ---"

# --- 2. SETUP UTENTE E SSH ---
USERNAME="tempuser"
PASSWORD="${BOOTSTRAP_PASSWORD}"
MOUNT_POINT="/mnt/vps"

echo "--> Creazione utente ${USERNAME} e impostazione password."
# Aggiungi l'utente e imposta la password
if ! id "$USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$USERNAME"
fi
echo "${USERNAME}:${PASSWORD}" | chpasswd

echo "--> Configurazione Sudo (NOPASSWD)."
# Concede sudo senza richiesta di password
echo "${USERNAME} ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/90-ansible-tempuser
chmod 0440 /etc/sudoers.d/90-ansible-tempuser

echo "--> Abilitazione SSH e installazione strumenti."
# Installazione minima per SSH e Ansible
if command -v apt-get >/dev/null; then
    apt-get update && apt-get install -y openssh-server mount util-linux tar coreutils e2fsprogs xfsprogs
    systemctl start sshd || service ssh start
elif command -v yum >/dev/null; then
    yum install -y openssh-server mount util-linux tar coreutils e2fsprogs xfsprogs
    systemctl start sshd || service ssh start
fi

# --- 3. PREPARAZIONE AMBIENTE ANSIBLE ---
echo "--> Creazione del mount point ${MOUNT_POINT}."
mkdir -p "$MOUNT_POINT"

echo "--- Bootstrap COMPLETATO ---"
echo "✅ Utente ${USERNAME} pronto. Procedi con il playbook Ansible."

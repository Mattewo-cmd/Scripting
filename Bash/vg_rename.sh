####################################################################################
# Description du script : Job bash qui renomme une machine et un VG Racine (Mode Chroot)
#                         Testé et fonctionnel sur Debian 13.3
#_Ver_|_Modifie_le_|_Par_|_Objet___________________________________________
#     |            |     |
# 1.0 | 23/0/2026 | MLE | Création du script
#     |            |     |
####################################################################################
#!/bin/bash

set -e # Arrête le script en cas d'erreur

if [[ $EUID -ne 0 ]]; then
   echo "Erreur: Ce script doit être exécuté en tant que root (ou via sudo)."
   exit 1
fi
# Désactiver TOUS les swaps immédiatement pour que le système ne les utilise plus
swapoff -a

echo  "--- Renommage de la machine ---"
read -p "Entrez le nouveau nom de la machine : " HOST


echo "$HOST" > /etc/hostname
sed -i "s/127.0.1.1.*/127.0.1.1\t$HOST/" /etc/hosts
echo "Nom de la machine changé en : $HOST"

echo "--- ÉTAPE 1 : Identification ---"
vgs
echo ""
read -p "Entrez le nom ACTUEL du VG : " ANCIEN_VG

NOUVEAU_VG="${HOST}-vg"
LV_ROOT="root"
#PART_BOOT="sda1"


# --- Remplacement simples tirets par des doubles ---
ANCIEN_VG_MAPPER=$(echo "$ANCIEN_VG" | sed 's/-/--/g')
NOUVEAU_VG_MAPPER=$(echo "$NOUVEAU_VG" | sed 's/-/--/g')
# -------------------------------------

# Vérification de l'existence du VG
if ! vgs "$ANCIEN_VG" > /dev/null 2>&1; then
    echo "Erreur : Le VG '$ANCIEN_VG' n'existe pas."
    exit 1
fi

echo "--- ÉTAPE 2 : Renommage du Volume Group ---"
vgrename "$ANCIEN_VG" "$NOUVEAU_VG"

vgscan
vgchange -ay "$NOUVEAU_VG"
vgmknodes

echo "--- ÉTAPE 3 : Préparation du Chroot ---"
MOUNT_POINT="/mnt/systeme"
mkdir -p $MOUNT_POINT

echo "Montage de la racine..."
# Utilisation du chemin /dev/mapper
mount "/dev/mapper/${NOUVEAU_VG_MAPPER}-${LV_ROOT}" $MOUNT_POINT

# --- PARTIE BOOT ---
read -p "Avez-vous une partition /boot séparée ? (y/n) : " HAS_BOOT
if [ "$HAS_BOOT" = "y" ]; then
    df -h | grep -E "Filesystem|boot"
    read -p "Entrez le nom de la partition boot (ex: sda1) : " PART_BOOT
    mount "/dev/$PART_BOOT" "$MOUNT_POINT/boot"
fi

# On part du principe qu'il y a un boot sur sda1
echo "Montage de /boot (par défaut /dev/$PART_BOOT)..."
mount "/dev/$PART_BOOT" "$MOUNT_POINT/boot" || echo "Note: Impossible de monter /dev/$PART_BOOT, ignoré."

echo "Liaison des systèmes de fichiers virtuels..."
for dir in /dev /proc /sys /run; do
    mount --bind $dir "$MOUNT_POINT$dir"
done

mkdir -p "$MOUNT_POINT/var/tmp"
chmod 1777 "$MOUNT_POINT/var/tmp"

echo "--- ÉTAPE 4 : Mise à jour de la configuration (sed) ---"
# Remplacement des noms simples
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/fstab
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/initramfs-tools/conf.d/* 2>/dev/null || true

# Remplacement des noms avec DOUBLES TIRETS
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/fstab
chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/initramfs-tools/conf.d/* 2>/dev/null || true

# Pour GRUB, on cible le fichier de config et la commande par défaut
if [ -f "$MOUNT_POINT/etc/default/grub" ]; then
    chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG/$NOUVEAU_VG/g" /etc/default/grub
    chroot $MOUNT_POINT sed -i "s/$ANCIEN_VG_MAPPER/$NOUVEAU_VG_MAPPER/g" /etc/default/grub
fi

echo "--- ÉTAPE 5 : Régénération Initramfs et GRUB ---"
chroot $MOUNT_POINT update-initramfs -u -k all
chroot $MOUNT_POINT update-grub

echo "--- ÉTAPE 6 : Nettoyage et Fin ---"
cd /

# On s'assure que rien ne tourne encore
sync

# On démonte dans l'ordre inverse du montage
# L'option -f force, -l (lazy) détache immédiatement
for dir in /dev/pts /dev/shm /dev /proc /sys /run; do
    umount -fl "$MOUNT_POINT$dir" 2>/dev/null || true
done

umount -fl "$MOUNT_POINT/boot" 2>/dev/null || true
umount -fl "$MOUNT_POINT" 2>/dev/null || true

# Suppression du répertoire de travail s'il est vide
rmdir $MOUNT_POINT 2>/dev/null || true

systemctl daemon-reload

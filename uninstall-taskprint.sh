#!/bin/bash

# =============================================================================
# Script de désinstallation TaskPrint
# =============================================================================

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
INSTALL_DIR="$HOME/taskprint-server"
SERVICE_NAME="taskprint"
USER_NAME=$(whoami)

print_step() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Confirmation utilisateur
confirm_uninstall() {
    echo ""
    echo "⚠️  ATTENTION: Cette opération va SUPPRIMER complètement TaskPrint"
    echo ""
    echo "Sera supprimé:"
    echo "  - Service systemd TaskPrint"
    echo "  - Conteneurs Docker"
    echo "  - Dossier $INSTALL_DIR"
    echo "  - Tâches cron"
    echo ""
    
    if [ "$1" != "--force" ]; then
        read -p "Voulez-vous continuer ? (oui/non): " response
        if [[ ! "$response" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
            echo "Désinstallation annulée."
            exit 0
        fi
    fi
    
    echo ""
    read -p "Créer une sauvegarde avant suppression ? (oui/non): " backup_response
    if [[ "$backup_response" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        create_final_backup
    fi
}

# Sauvegarde finale
create_final_backup() {
    print_step "Création de la sauvegarde finale..."
    
    if [ -d "$INSTALL_DIR" ]; then
        BACKUP_FILE="$HOME/taskprint_final_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        
        tar -czf "$BACKUP_FILE" \
            -C "$HOME" \
            taskprint-server/data \
            taskprint-server/app/uploads \
            taskprint-server/docker-compose.yml \
            taskprint-server/nginx/nginx.conf 2>/dev/null || true
        
        print_success "Sauvegarde créée: $BACKUP_FILE"
    fi
}

# Arrêt et suppression du service systemd
remove_systemd_service() {
    print_step "Suppression du service systemd..."
    
    # Arrêter le service
    if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        sudo systemctl stop $SERVICE_NAME
        print_success "Service $SERVICE_NAME arrêté"
    fi
    
    # Désactiver le service
    if sudo systemctl is-enabled --quiet $SERVICE_NAME 2>/dev/null; then
        sudo systemctl disable $SERVICE_NAME
        print_success "Service $SERVICE_NAME désactivé"
    fi
    
    # Supprimer le fichier service
    if [ -f "/etc/systemd/system/$SERVICE_NAME.service" ]; then
        sudo rm "/etc/systemd/system/$SERVICE_NAME.service"
        sudo systemctl daemon-reload
        print_success "Fichier service supprimé"
    fi
}

# Arrêt et suppression des conteneurs Docker
remove_docker_containers() {
    print_step "Suppression des conteneurs Docker..."
    
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
        cd "$INSTALL_DIR"
        
        # Arrêt des conteneurs
        docker-compose down -v --remove-orphans 2>/dev/null || true
        
        # Suppression des images
        docker-compose down --rmi all 2>/dev/null || true
        
        print_success "Conteneurs Docker supprimés"
    fi
    
    # Nettoyage général Docker
    docker system prune -f 2>/dev/null || true
}

# Suppression des tâches cron
remove_cron_jobs() {
    print_step "Suppression des tâches cron..."
    
    # Sauvegarder le crontab actuel sans les tâches TaskPrint
    (crontab -l 2>/dev/null || echo "") | grep -v "taskprint" | grep -v "$INSTALL_DIR" > /tmp/crontab_clean
    
    # Appliquer le nouveau crontab
    crontab /tmp/crontab_clean 2>/dev/null || true
    rm -f /tmp/crontab_clean
    
    print_success "Tâches cron supprimées"
}

# Suppression des dossiers et fichiers
remove_files() {
    print_step "Suppression des fichiers..."
    
    if [ -d "$INSTALL_DIR" ]; then
        # Arrêter tous les processus utilisant le dossier
        fuser -k "$INSTALL_DIR" 2>/dev/null || true
        
        # Supprimer le dossier
        rm -rf "$INSTALL_DIR"
        print_success "Dossier $INSTALL_DIR supprimé"
    fi
    
    # Suppression des logs nginx spécifiques (si ils existent)
    sudo rm -f /var/log/nginx/taskprint_* 2>/dev/null || true
}

# Nettoyage des résidus système
cleanup_system() {
    print_step "Nettoyage des résidus système..."
    
    # Supprimer les entrées du fichier hosts si elles existent
    if grep -q "taskprint.local" /etc/hosts 2>/dev/null; then
        sudo sed -i '/taskprint.local/d' /etc/hosts
        print_success "Entrées DNS locales supprimées"
    fi
    
    # Nettoyage Docker complet (optionnel)
    read -p "Nettoyer complètement Docker (supprime TOUTES les images non utilisées) ? (oui/non): " docker_clean
    if [[ "$docker_clean" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        docker system prune -a -f --volumes 2>/dev/null || true
        print_success "Nettoyage Docker complet effectué"
    fi
}

# Désinstallation optionnelle de Docker
remove_docker() {
    print_step "Docker est-il utilisé par d'autres applications ?"
    
    # Compter les conteneurs non-TaskPrint
    OTHER_CONTAINERS=$(docker ps -a --format '{{.Names}}' 2>/dev/null | grep -v taskprint | wc -l || echo "0")
    
    if [ "$OTHER_CONTAINERS" -gt 0 ]; then
        print_warning "Docker est utilisé par d'autres conteneurs ($OTHER_CONTAINERS trouvés)"
        print_warning "Docker ne sera PAS désinstallé"
        return
    fi
    
    read -p "Désinstaller Docker complètement ? (oui/non): " docker_remove
    if [[ "$docker_remove" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        print_step "Désinstallation de Docker..."
        
        # Arrêt du service Docker
        sudo systemctl stop docker 2>/dev/null || true
        sudo systemctl disable docker 2>/dev/null || true
        
        # Suppression des paquets Docker
        sudo apt remove -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-compose 2>/dev/null || true
        sudo apt autoremove -y 2>/dev/null || true
        
        # Suppression des données Docker
        sudo rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true
        
        # Suppression du groupe docker
        sudo groupdel docker 2>/dev/null || true
        
        # Suppression des clés et repositories
        sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
        
        print_success "Docker désinstallé complètement"
    fi
}

# Vérification finale
final_check() {
    print_step "Vérification finale..."
    
    local issues_found=0
    
    # Vérifier service systemd
    if sudo systemctl list-unit-files | grep -q "$SERVICE_NAME" 2>/dev/null; then
        print_warning "Service systemd toujours présent"
        issues_found=$((issues_found + 1))
    fi
    
    # Vérifier dossiers
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Dossier d'installation toujours présent"
        issues_found=$((issues_found + 1))
    fi
    
    # Vérifier conteneurs
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q taskprint; then
        print_warning "Conteneurs TaskPrint toujours présents"
        issues_found=$((issues_found + 1))
    fi
    
    # Vérifier cron
    if crontab -l 2>/dev/null | grep -q "taskprint"; then
        print_warning "Tâches cron TaskPrint toujours présentes"
        issues_found=$((issues_found + 1))
    fi
    
    if [ $issues_found -eq 0 ]; then
        print_success "Désinstallation complète vérifiée ✅"
    else
        print_warning "Désinstallation terminée avec $issues_found avertissement(s)"
    fi
}

# Affichage des informations de fin
show_final_info() {
    echo ""
    echo "========================================"
    echo "🗑️  TaskPrint désinstallé avec succès"
    echo "========================================"
    echo ""
    echo "📊 Résumé des actions:"
    echo "  ✅ Service systemd supprimé"
    echo "  ✅ Conteneurs Docker supprimés"
    echo "  ✅ Fichiers de configuration supprimés"
    echo "  ✅ Tâches cron supprimées"
    echo "  ✅ Nettoyage système effectué"
    echo ""
    
    # Afficher les sauvegardes disponibles
    BACKUP_FILES=$(find "$HOME" -name "taskprint_*backup*.tar.gz" 2>/dev/null | head -5)
    if [ ! -z "$BACKUP_FILES" ]; then
        echo "💾 Sauvegardes disponibles:"
        echo "$BACKUP_FILES" | while read -r file; do
            size=$(du -h "$file" 2>/dev/null | cut -f1)
            echo "   📁 $(basename "$file") ($size)"
        done
        echo ""
    fi
    
    echo "🔄 Pour réinstaller TaskPrint:"
    echo "   ./install-taskprint.sh"
    echo ""
    echo "🗑️  Pour supprimer les sauvegardes:"
    echo "   rm -f ~/taskprint_*backup*.tar.gz"
    echo ""
    echo "========================================"
    echo "Merci d'avoir utilisé TaskPrint ! 👋"
    echo "========================================"
}

# Menu interactif
show_menu() {
    echo ""
    echo "🗑️  Script de désinstallation TaskPrint"
    echo "======================================"
    echo ""
    echo "Options disponibles:"
    echo "  1. Désinstallation complète (recommandé)"
    echo "  2. Désinstallation partielle (garder Docker)"
    echo "  3. Arrêter seulement le service (temporaire)"
    echo "  4. Créer une sauvegarde et quitter"
    echo "  5. Afficher l'état actuel"
    echo "  6. Quitter"
    echo ""
    read -p "Choisissez une option (1-6): " choice
    
    case $choice in
        1)
            confirm_uninstall
            full_uninstall
            ;;
        2)
            confirm_uninstall
            partial_uninstall
            ;;
        3)
            stop_service_only
            ;;
        4)
            create_final_backup
            echo "Sauvegarde créée. Désinstallation annulée."
            ;;
        5)
            show_current_status
            ;;
        6)
            echo "Au revoir !"
            exit 0
            ;;
        *)
            print_error "Option invalide"
            show_menu
            ;;
    esac
}

# Désinstallation complète
full_uninstall() {
    remove_systemd_service
    remove_docker_containers
    remove_cron_jobs
    remove_files
    cleanup_system
    remove_docker
    final_check
    show_final_info
}

# Désinstallation partielle
partial_uninstall() {
    remove_systemd_service
    remove_docker_containers
    remove_cron_jobs
    remove_files
    cleanup_system
    final_check
    show_final_info
}

# Arrêt du service seulement
stop_service_only() {
    print_step "Arrêt temporaire du service TaskPrint..."
    
    sudo systemctl stop $SERVICE_NAME 2>/dev/null || true
    
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        docker-compose stop 2>/dev/null || true
    fi
    
    print_success "Service TaskPrint arrêté temporairement"
    echo "Pour le redémarrer: sudo systemctl start $SERVICE_NAME"
}

# Afficher l'état actuel
show_current_status() {
    echo ""
    echo "📊 État actuel de TaskPrint"
    echo "========================="
    echo ""
    
    # Service systemd
    echo "🔧 Service systemd:"
    if sudo systemctl is-active --quiet $SERVICE_NAME 2>/dev/null; then
        echo "   ✅ Actif"
    else
        echo "   ❌ Inactif"
    fi
    
    # Conteneurs Docker
    echo ""
    echo "🐳 Conteneurs Docker:"
    if [ -d "$INSTALL_DIR" ]; then
        cd "$INSTALL_DIR"
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            echo "   ✅ En cours d'exécution"
            docker-compose ps 2>/dev/null | grep taskprint || true
        else
            echo "   ❌ Arrêtés"
        fi
    else
        echo "   ❌ Dossier d'installation non trouvé"
    fi
    
    # Fichiers
    echo ""
    echo "📁 Installation:"
    if [ -d "$INSTALL_DIR" ]; then
        size=$(du -sh "$INSTALL_DIR" 2>/dev/null | cut -f1)
        echo "   ✅ Dossier présent ($size)"
    else
        echo "   ❌ Dossier absent"
    fi
    
    # Tâches cron
    echo ""
    echo "⏰ Tâches programmées:"
    cron_count=$(crontab -l 2>/dev/null | grep -c "taskprint" || echo "0")
    if [ "$cron_count" -gt 0 ]; then
        echo "   ✅ $cron_count tâche(s) programmée(s)"
    else
        echo "   ❌ Aucune tâche programmée"
    fi
    
    echo ""
    read -p "Appuyez sur Entrée pour revenir au menu..."
    show_menu
}

# Fonction principale
main() {
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo "Script de désinstallation TaskPrint"
        echo ""
        echo "Usage:"
        echo "  $0                 # Menu interactif"
        echo "  $0 --force         # Désinstallation complète sans confirmation"
        echo "  $0 --partial       # Désinstallation partielle sans confirmation"
        echo "  $0 --stop          # Arrêter le service seulement"
        echo "  $0 --status        # Afficher l'état actuel"
        echo "  $0 --help          # Afficher cette aide"
        exit 0
    fi
    
    case "$1" in
        --force)
            confirm_uninstall --force
            full_uninstall
            ;;
        --partial)
            confirm_uninstall --force
            partial_uninstall
            ;;
        --stop)
            stop_service_only
            ;;
        --status)
            show_current_status
            ;;
        *)
            show_menu
            ;;
    esac
}

# Point d'entrée
main "$@"
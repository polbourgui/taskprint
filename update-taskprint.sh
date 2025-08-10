#!/bin/bash

# =============================================================================
# TaskPrint - Script de mise à jour depuis GitHub
# Repository: https://github.com/polbourgui/taskprint
# =============================================================================

set -e

# Configuration
REPO_URL="https://github.com/polbourgui/taskprint.git"
INSTALL_DIR="$HOME/taskprint-server"
BACKUP_DIR="$INSTALL_DIR/backups"
TEMP_DIR="/tmp/taskprint-update"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}[MISE À JOUR]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✅ OK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠️  ATTENTION]${NC} $1"
}

print_error() {
    echo -e "${RED}[❌ ERREUR]${NC} $1"
}

print_info() {
    echo -e "${CYAN}[ℹ️  INFO]${NC} $1"
}

print_header() {
    clear
    echo -e "${PURPLE}"
    echo "████████╗ █████╗ ███████╗██╗  ██╗██████╗ ██████╗ ██╗███╗   ██╗████████╗"
    echo "╚══██╔══╝██╔══██╗██╔════╝██║ ██╔╝██╔══██╗██╔══██╗██║████╗  ██║╚══██╔══╝"
    echo "   ██║   ███████║███████╗█████╔╝ ██████╔╝██████╔╝██║██╔██╗ ██║   ██║   "
    echo "   ██║   ██╔══██║╚════██║██╔═██╗ ██╔═══╝ ██╔══██╗██║██║╚██╗██║   ██║   "
    echo "   ██║   ██║  ██║███████║██║  ██╗██║     ██║  ██║██║██║ ╚████║   ██║   "
    echo "   ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ╚═╝   "
    echo -e "${NC}"
    echo -e "${CYAN}🔄 Mise à jour depuis GitHub${NC}"
    echo -e "${BLUE}📁 Repository: https://github.com/polbourgui/taskprint${NC}"
    echo ""
}

# Vérifier l'installation existante
check_existing_installation() {
    print_step "Vérification de l'installation existante..."
    
    if [[ ! -d "$INSTALL_DIR" ]]; then
        print_error "Installation TaskPrint non trouvée dans $INSTALL_DIR"
        print_info "Utilisez le script d'installation initial à la place"
        exit 1
    fi
    
    if [[ ! -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        print_error "Installation TaskPrint incomplète détectée"
        exit 1
    fi
    
    print_success "Installation existante trouvée"
}

# Vérifier les nouvelles versions
check_for_updates() {
    print_step "Vérification des mises à jour disponibles..."
    
    # Obtenir la version locale (si disponible)
    local local_version="unknown"
    if [[ -f "$INSTALL_DIR/.git/HEAD" ]]; then
        cd "$INSTALL_DIR"
        local_version=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi
    
    # Obtenir la dernière version distante
    local remote_version=$(git ls-remote --heads "$REPO_URL" main | cut -c1-7)
    
    echo -e "${CYAN}Version locale:${NC} $local_version"
    echo -e "${CYAN}Version distante:${NC} $remote_version"
    
    if [[ "$local_version" == "$remote_version" ]]; then
        print_info "Vous avez déjà la dernière version"
        read -p "Forcer la mise à jour quand même ? (oui/non): " force_update
        if [[ ! "$force_update" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
            print_info "Mise à jour annulée"
            exit 0
        fi
    else
        print_warning "Nouvelle version disponible"
    fi
}

# Créer une sauvegarde avant mise à jour
create_backup() {
    print_step "Création d'une sauvegarde avant mise à jour..."
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="update_backup_$backup_timestamp"
    local full_backup_dir="$BACKUP_DIR/$backup_name"
    
    mkdir -p "$full_backup_dir"
    
    # Sauvegarder les données critiques
    print_info "Sauvegarde des données utilisateur..."
    if [[ -d "$INSTALL_DIR/data" ]]; then
        cp -r "$INSTALL_DIR/data" "$full_backup_dir/"
    fi
    
    if [[ -d "$INSTALL_DIR/app/uploads" ]]; then
        cp -r "$INSTALL_DIR/app/uploads" "$full_backup_dir/"
    fi
    
    # Sauvegarder la configuration
    print_info "Sauvegarde de la configuration..."
    cp "$INSTALL_DIR/docker-compose.yml" "$full_backup_dir/" 2>/dev/null || true
    if [[ -d "$INSTALL_DIR/nginx" ]]; then
        cp -r "$INSTALL_DIR/nginx" "$full_backup_dir/"
    fi
    
    # Créer un archive compressée
    cd "$BACKUP_DIR"
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_name"
    
    print_success "Sauvegarde créée: $BACKUP_DIR/${backup_name}.tar.gz"
    echo "export TASKPRINT_BACKUP_FILE='$BACKUP_DIR/${backup_name}.tar.gz'" > /tmp/taskprint_backup_info
}

# Arrêter les services
stop_services() {
    print_step "Arrêt des services TaskPrint..."
    
    # Arrêt du service systemd
    if systemctl --user is-active --quiet taskprint 2>/dev/null; then
        systemctl --user stop taskprint
        print_success "Service utilisateur arrêté"
    elif sudo systemctl is-active --quiet taskprint 2>/dev/null; then
        sudo systemctl stop taskprint
        print_success "Service système arrêté"
    fi
    
    # Arrêt des conteneurs Docker
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        cd "$INSTALL_DIR"
        docker-compose down 2>/dev/null || true
        print_success "Conteneurs Docker arrêtés"
    fi
}

# Télécharger la nouvelle version
download_update() {
    print_step "Téléchargement de la nouvelle version..."
    
    # Nettoyer le dossier temporaire
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Cloner la nouvelle version
    print_info "Téléchargement depuis GitHub..."
    git clone "$REPO_URL" "$TEMP_DIR" --depth 1
    
    print_success "Nouvelle version téléchargée"
}

# Appliquer la mise à jour
apply_update() {
    print_step "Application de la mise à jour..."
    
    # Sauvegarder les fichiers de données avant remplacement
    local temp_data_dir="/tmp/taskprint_data_temp"
    if [[ -d "$INSTALL_DIR/data" ]]; then
        cp -r "$INSTALL_DIR/data" "$temp_data_dir"
    fi
    
    local temp_uploads_dir="/tmp/taskprint_uploads_temp"
    if [[ -d "$INSTALL_DIR/app/uploads" ]]; then
        cp -r "$INSTALL_DIR/app/uploads" "$temp_uploads_dir"
    fi
    
    # Remplacer les fichiers de code
    print_info "Mise à jour du code source..."
    
    # Fichiers principaux à mettre à jour
    local files_to_update=(
        "app/server.js"
        "app/package.json"
        "app/Dockerfile"
        "nginx/nginx.conf"
        "docker-compose.yml"
        "install-taskprint.sh"
        "backup-taskprint.sh"
        "monitor-taskprint.sh"
        "update-taskprint.sh"
    )
    
    for file in "${files_to_update[@]}"; do
        if [[ -f "$TEMP_DIR/$file" ]]; then
            local target_dir="$INSTALL_DIR/$(dirname "$file")"
            mkdir -p "$target_dir"
            cp "$TEMP_DIR/$file" "$target_dir/"
            print_info "Mis à jour: $file"
        fi
    done
    
    # Restaurer les données utilisateur
    if [[ -d "$temp_data_dir" ]]; then
        rm -rf "$INSTALL_DIR/data" 2>/dev/null || true
        mv "$temp_data_dir" "$INSTALL_DIR/data"
        print_info "Données utilisateur restaurées"
    fi
    
    if [[ -d "$temp_uploads_dir" ]]; then
        rm -rf "$INSTALL_DIR/app/uploads" 2>/dev/null || true
        mv "$temp_uploads_dir" "$INSTALL_DIR/app/uploads"
        print_info "Images utilisateur restaurées"
    fi
    
    # Mise à jour de l'interface web si une nouvelle version existe
    if [[ -f "$TEMP_DIR/app/public/index.html" ]]; then
        cp "$TEMP_DIR/app/public/index.html" "$INSTALL_DIR/app/public/"
        print_info "Interface web mise à jour"
    fi
    
    print_success "Mise à jour appliquée"
}

# Reconstruire et redémarrer
rebuild_and_restart() {
    print_step "Reconstruction et redémarrage des services..."
    
    cd "$INSTALL_DIR"
    
    # Mettre à jour les dépendances Node.js
    if [[ -f "app/package.json" ]]; then
        print_info "Reconstruction de l'image Docker..."
        docker-compose build --no-cache
    fi
    
    # Redémarrer les services
    print_info "Redémarrage des conteneurs..."
    docker-compose up -d
    
    # Attendre que les services soient prêts
    print_info "Vérification du démarrage des services..."
    sleep 15
    
    # Redémarrer le service systemd
    if systemctl --user list-unit-files | grep -q taskprint; then
        systemctl --user start taskprint
        print_success "Service utilisateur redémarré"
    elif sudo systemctl list-unit-files | grep -q taskprint; then
        sudo systemctl start taskprint
        print_success "Service système redémarré"
    fi
    
    print_success "Services redémarrés"
}

# Vérifier que la mise à jour fonctionne
verify_update() {
    print_step "Vérification de la mise à jour..."
    
    # Vérifier les conteneurs Docker
    if ! docker-compose ps | grep -q "Up"; then
        print_error "Les conteneurs ne sont pas démarrés correctement"
        return 1
    fi
    
    # Vérifier l'accès HTTP
    local max_attempts=6
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if curl -f -s http://localhost/health > /dev/null 2>&1; then
            print_success "Service HTTP accessible"
            break
        fi
        
        attempt=$((attempt + 1))
        if [[ $attempt -eq $max_attempts ]]; then
            print_error "Service HTTP inaccessible après $max_attempts tentatives"
            return 1
        fi
        
        print_info "Tentative $attempt/$max_attempts - Attente..."
        sleep 10
    done
    
    # Vérifier l'API
    if curl -f -s http://localhost/api/tasks > /dev/null 2>&1; then
        print_success "API accessible et fonctionnelle"
    else
        print_warning "API pas encore accessible, mais le service principal fonctionne"
    fi
    
    print_success "Mise à jour vérifiée avec succès"
    return 0
}

# Restaurer depuis la sauvegarde en cas d'échec
restore_from_backup() {
    print_error "Échec de la mise à jour - Restauration depuis la sauvegarde..."
    
    if [[ -f /tmp/taskprint_backup_info ]]; then
        source /tmp/taskprint_backup_info
        
        if [[ -f "$TASKPRINT_BACKUP_FILE" ]]; then
            print_info "Restauration depuis: $TASKPRINT_BACKUP_FILE"
            
            # Arrêter les services défaillants
            cd "$INSTALL_DIR"
            docker-compose down 2>/dev/null || true
            
            # Extraire la sauvegarde
            cd "$BACKUP_DIR"
            tar -xzf "$(basename "$TASKPRINT_BACKUP_FILE")"
            local backup_folder=$(basename "$TASKPRINT_BACKUP_FILE" .tar.gz)
            
            # Restaurer les données
            if [[ -d "$backup_folder/data" ]]; then
                rm -rf "$INSTALL_DIR/data"
                cp -r "$backup_folder/data" "$INSTALL_DIR/"
            fi
            
            if [[ -d "$backup_folder/uploads" ]]; then
                rm -rf "$INSTALL_DIR/app/uploads"
                cp -r "$backup_folder/uploads" "$INSTALL_DIR/app/"
            fi
            
            # Restaurer la configuration
            if [[ -f "$backup_folder/docker-compose.yml" ]]; then
                cp "$backup_folder/docker-compose.yml" "$INSTALL_DIR/"
            fi
            
            if [[ -d "$backup_folder/nginx" ]]; then
                rm -rf "$INSTALL_DIR/nginx"
                cp -r "$backup_folder/nginx" "$INSTALL_DIR/"
            fi
            
            # Redémarrer avec l'ancienne configuration
            cd "$INSTALL_DIR"
            docker-compose up -d
            
            print_success "Restauration terminée - Ancienne version rétablie"
            
            # Nettoyer
            rm -rf "$backup_folder"
        else
            print_error "Fichier de sauvegarde non trouvé"
        fi
    else
        print_error "Informations de sauvegarde non trouvées"
    fi
}

# Nettoyer les fichiers temporaires
cleanup() {
    print_step "Nettoyage des fichiers temporaires..."
    
    # Supprimer le dossier temporaire
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Nettoyer les fichiers temporaires de données
    rm -rf /tmp/taskprint_data_temp /tmp/taskprint_uploads_temp 2>/dev/null || true
    rm -f /tmp/taskprint_backup_info 2>/dev/null || true
    
    # Nettoyage Docker
    docker system prune -f 2>/dev/null || true
    
    print_success "Nettoyage terminé"
}

# Afficher le résumé final
show_update_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    print_header
    echo -e "${GREEN}🎉 Mise à jour TaskPrint Terminée avec Succès ! 🎉${NC}"
    echo ""
    echo -e "${CYAN}📍 Votre TaskPrint mis à jour est accessible à:${NC}"
    echo -e "   🏠 Local:    ${YELLOW}http://localhost${NC}"
    echo -e "   🌐 Réseau:   ${YELLOW}http://$ip_address${NC}"
    echo ""
    echo -e "${CYAN}✨ Nouveautés potentielles de cette mise à jour:${NC}"
    echo -e "   🔧 Améliorations de performance"
    echo -e "   🐛 Corrections de bugs"
    echo -e "   🚀 Nouvelles fonctionnalités"
    echo -e "   🔒 Mises à jour de sécurité"
    echo ""
    echo -e "${CYAN}🔍 Vérifications recommandées:${NC}"
    echo -e "   ✅ Testez l'interface web"
    echo -e "   ✅ Vérifiez vos tâches existantes"
    echo -e "   ✅ Testez la prise de photo"
    echo -e "   ✅ Vérifiez l'impression"
    echo ""
    echo -e "${CYAN}📊 Commandes utiles:${NC}"
    echo -e "   🔍 Status: ${YELLOW}sudo systemctl status taskprint${NC}"
    echo -e "   📋 Logs: ${YELLOW}docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f${NC}"
    echo -e "   🏥 Santé: ${YELLOW}curl http://localhost/health${NC}"
    echo ""
    
    # Afficher les informations de sauvegarde
    if [[ -f /tmp/taskprint_backup_info ]]; then
        source /tmp/taskprint_backup_info
        echo -e "${CYAN}💾 Sauvegarde créée:${NC}"
        echo -e "   📁 ${YELLOW}$TASKPRINT_BACKUP_FILE${NC}"
        echo -e "   ℹ️  Vous pouvez la supprimer si tout fonctionne bien"
        echo ""
    fi
    
    echo -e "${GREEN}🚀 Votre TaskPrint est maintenant à jour !${NC}"
    echo ""
}

# Menu de mise à jour
show_update_menu() {
    print_header
    echo -e "${CYAN}🔄 Mise à jour TaskPrint depuis GitHub${NC}"
    echo ""
    echo -e "${YELLOW}Choisissez le type de mise à jour:${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🚀 Mise à jour automatique (Recommandé)"
    echo -e "  ${GREEN}2)${NC} 🔍 Vérifier les mises à jour disponibles"
    echo -e "  ${GREEN}3)${NC} 🔧 Mise à jour forcée (ignorer la version)"
    echo -e "  ${GREEN}4)${NC} 💾 Créer une sauvegarde seulement"
    echo -e "  ${GREEN}5)${NC} 📊 Vérifier l'état actuel"
    echo -e "  ${GREEN}6)${NC} 🔄 Redémarrer les services seulement"
    echo -e "  ${GREEN}0)${NC} ❌ Quitter"
    echo ""
    read -p "Votre choix (0-6): " choice
    
    case $choice in
        1)
            automatic_update
            ;;
        2)
            check_updates_only
            ;;
        3)
            forced_update
            ;;
        4)
            backup_only
            ;;
        5)
            check_current_status
            ;;
        6)
            restart_services_only
            ;;
        0)
            print_info "Au revoir ! 👋"
            exit 0
            ;;
        *)
            print_error "Choix invalide. Veuillez choisir entre 0 et 6."
            sleep 2
            show_update_menu
            ;;
    esac
}

# Mise à jour automatique
automatic_update() {
    print_step "🚀 Mise à jour automatique de TaskPrint"
    echo ""
    
    check_existing_installation
    check_for_updates
    create_backup
    stop_services
    download_update
    apply_update
    rebuild_and_restart
    
    if verify_update; then
        cleanup
        show_update_summary
    else
        print_error "La mise à jour a échoué"
        restore_from_backup
        cleanup
        exit 1
    fi
}

# Vérification des mises à jour seulement
check_updates_only() {
    print_step "🔍 Vérification des mises à jour disponibles"
    echo ""
    
    check_existing_installation
    check_for_updates
    
    # Afficher les informations sur les commits récents
    print_info "Récupération de l'historique des changements..."
    
    # Obtenir les derniers commits
    local recent_commits=$(git ls-remote --heads "$REPO_URL" main)
    if [[ ! -z "$recent_commits" ]]; then
        print_info "Derniers changements disponibles sur GitHub"
    fi
    
    echo ""
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_update_menu
}

# Mise à jour forcée
forced_update() {
    print_step "🔧 Mise à jour forcée"
    echo ""
    print_warning "Cette opération va forcer la mise à jour même si vous avez la dernière version"
    read -p "Êtes-vous sûr de vouloir continuer ? (oui/non): " confirm
    if [[ ! "$confirm" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        show_update_menu
        return
    fi
    
    check_existing_installation
    create_backup
    stop_services
    download_update
    apply_update
    rebuild_and_restart
    
    if verify_update; then
        cleanup
        show_update_summary
    else
        print_error "La mise à jour forcée a échoué"
        restore_from_backup
        cleanup
        exit 1
    fi
}

# Sauvegarde seulement
backup_only() {
    print_step "💾 Création d'une sauvegarde"
    echo ""
    
    check_existing_installation
    create_backup
    
    print_success "Sauvegarde créée avec succès"
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_update_menu
}

# Vérifier l'état actuel
check_current_status() {
    print_step "📊 Vérification de l'état actuel"
    echo ""
    
    # État de l'installation
    if [[ -d "$INSTALL_DIR" ]]; then
        print_success "Installation TaskPrint trouvée"
        echo "   📁 Dossier: $INSTALL_DIR"
        
        # Vérifier Git
        if [[ -d "$INSTALL_DIR/.git" ]]; then
            cd "$INSTALL_DIR"
            local current_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
            print_info "Version locale: $current_commit"
        else
            print_warning "Pas de repository Git local (installation manuelle)"
        fi
    else
        print_error "Installation TaskPrint non trouvée"
    fi
    
    echo ""
    
    # État des services
    print_info "État des services:"
    
    # Service systemd
    if systemctl --user is-active --quiet taskprint 2>/dev/null; then
        print_success "Service utilisateur: actif"
    elif sudo systemctl is-active --quiet taskprint 2>/dev/null; then
        print_success "Service système: actif"
    else
        print_warning "Service systemd: inactif"
    fi
    
    # Conteneurs Docker
    if [[ -f "$INSTALL_DIR/docker-compose.yml" ]]; then
        cd "$INSTALL_DIR"
        if docker-compose ps | grep -q "Up"; then
            print_success "Conteneurs Docker: actifs"
            docker-compose ps
        else
            print_warning "Conteneurs Docker: arrêtés"
        fi
    else
        print_warning "Configuration Docker non trouvée"
    fi
    
    echo ""
    
    # Test de connectivité
    print_info "Test de connectivité:"
    if curl -f -s http://localhost/health > /dev/null 2>&1; then
        print_success "Interface web: accessible"
    else
        print_warning "Interface web: inaccessible"
    fi
    
    echo ""
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_update_menu
}

# Redémarrer les services seulement
restart_services_only() {
    print_step "🔄 Redémarrage des services TaskPrint"
    echo ""
    
    check_existing_installation
    
    # Arrêter les services
    print_info "Arrêt des services..."
    stop_services
    
    # Redémarrer
    print_info "Redémarrage des services..."
    rebuild_and_restart
    
    # Vérifier
    if verify_update; then
        print_success "Services redémarrés avec succès"
    else
        print_error "Problème lors du redémarrage"
    fi
    
    echo ""
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_update_menu
}

# Gestion des erreurs
handle_error() {
    print_error "Une erreur est survenue durant la mise à jour"
    
    if [[ -f /tmp/taskprint_backup_info ]]; then
        print_warning "Tentative de restauration automatique..."
        restore_from_backup
    fi
    
    cleanup
    exit 1
}

# Configuration des traps
trap 'handle_error' ERR

# Point d'entrée principal
main() {
    case "${1:-}" in
        --auto|--automatic)
            print_header
            automatic_update
            ;;
        --check)
            print_header
            check_updates_only
            ;;
        --force|--forced)
            print_header
            forced_update
            ;;
        --backup)
            print_header
            backup_only
            ;;
        --status)
            print_header
            check_current_status
            ;;
        --restart)
            print_header
            restart_services_only
            ;;
        --help|-h)
            print_header
            echo -e "${CYAN}🔄 Script de mise à jour TaskPrint${NC}"
            echo ""
            echo "Usage:"
            echo "  $0                 # Menu interactif"
            echo "  $0 --auto          # Mise à jour automatique"
            echo "  $0 --check         # Vérifier les mises à jour"
            echo "  $0 --force         # Mise à jour forcée"
            echo "  $0 --backup        # Créer une sauvegarde"
            echo "  $0 --status        # Vérifier l'état actuel"
            echo "  $0 --restart       # Redémarrer les services"
            echo "  $0 --help          # Afficher cette aide"
            echo ""
            echo "Repository: https://github.com/polbourgui/taskprint"
            ;;
        --version|-v)
            echo "TaskPrint Update Script v1.0"
            echo "Repository: https://github.com/polbourgui/taskprint"
            ;;
        *)
            show_update_menu
            ;;
    esac
}

# Vérification si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
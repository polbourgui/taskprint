#!/bin/bash

# =============================================================================
# TaskPrint - Installation Rapide pour NUC Intel Home Lab
# Repository: https://github.com/polbourgui/taskprint
# =============================================================================

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/polbourgui/taskprint.git"
INSTALL_DIR="$HOME/taskprint-server"
TEMP_DIR="/tmp/taskprint-install"

# Fonctions d'affichage
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
    echo -e "${CYAN}🏠 Gestionnaire de Tâches pour Home Lab - Installation Rapide${NC}"
    echo -e "${BLUE}📁 Repository: https://github.com/polbourgui/taskprint${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}[ÉTAPE]${NC} $1"
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

# Vérification de l'environnement
check_environment() {
    print_step "Vérification de l'environnement..."
    
    # Vérifier l'OS
    if [[ ! -f /etc/debian_version ]]; then
        print_error "Ce script nécessite Ubuntu/Debian"
        exit 1
    fi
    
    # Vérifier les privilèges sudo
    if ! sudo -n true 2>/dev/null; then
        print_error "Ce script nécessite les privilèges sudo"
        print_info "Exécutez: sudo -v avant de relancer"
        exit 1
    fi
    
    # Vérifier la connectivité Internet
    if ! ping -c 1 github.com &> /dev/null; then
        print_error "Pas de connexion Internet détectée"
        exit 1
    fi
    
    print_success "Environnement compatible détecté"
}

# Détection du matériel
detect_hardware() {
    print_step "Détection du matériel..."
    
    # Informations système
    local cpu_info=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
    local mem_total=$(free -h | grep Mem | awk '{print $2}')
    local disk_space=$(df -h / | tail -1 | awk '{print $4}')
    
    echo -e "${CYAN}💻 CPU:${NC} $cpu_info"
    echo -e "${CYAN}💾 RAM:${NC} $mem_total"
    echo -e "${CYAN}💽 Espace libre:${NC} $disk_space"
    
    # Détecter si c'est un NUC Intel
    if lscpu | grep -q "Intel"; then
        print_success "NUC Intel détecté - Configuration optimale"
    else
        print_warning "Matériel non-Intel détecté - Compatible mais non testé"
    fi
    
    # Vérifier l'espace disque minimum
    local disk_gb=$(df / | tail -1 | awk '{print $4}')
    if [[ $disk_gb -lt 2000000 ]]; then  # 2GB en KB
        print_warning "Moins de 2GB d'espace libre détecté"
        read -p "Continuer quand même ? (oui/non): " response
        if [[ ! "$response" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
            exit 0
        fi
    fi
}

# Installation des prérequis
install_prerequisites() {
    print_step "Installation des prérequis..."
    
    # Mise à jour des paquets
    print_info "Mise à jour de la liste des paquets..."
    sudo apt update -qq
    
    # Installer git si nécessaire
    if ! command -v git &> /dev/null; then
        print_info "Installation de Git..."
        sudo apt install -y git
    fi
    
    # Installer curl si nécessaire
    if ! command -v curl &> /dev/null; then
        print_info "Installation de Curl..."
        sudo apt install -y curl
    fi
    
    print_success "Prérequis installés"
}

# Téléchargement du code source
download_source() {
    print_step "Téléchargement du code source TaskPrint..."
    
    # Nettoyer les installations précédentes
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Installation existante détectée"
        read -p "Sauvegarder l'installation actuelle ? (oui/non): " backup_response
        if [[ "$backup_response" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
            local backup_name="${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
            mv "$INSTALL_DIR" "$backup_name"
            print_success "Sauvegarde créée: $backup_name"
        else
            rm -rf "$INSTALL_DIR"
        fi
    fi
    
    # Cloner le repository
    print_info "Clonage depuis GitHub..."
    git clone "$REPO_URL" "$TEMP_DIR" --depth 1
    
    # Déplacer vers le dossier final
    mv "$TEMP_DIR" "$INSTALL_DIR"
    
    print_success "Code source téléchargé"
}

# Lancement de l'installation principale
run_main_installer() {
    print_step "Lancement de l'installation principale..."
    
    cd "$INSTALL_DIR"
    
    # Vérifier que le script principal existe
    if [[ ! -f "install-taskprint.sh" ]]; then
        print_error "Script d'installation principal non trouvé"
        print_info "Vérifiez le contenu du repository"
        ls -la "$INSTALL_DIR"
        exit 1
    fi
    
    # Rendre le script exécutable
    chmod +x install-taskprint.sh
    
    # Exécuter l'installation
    print_info "Démarrage de l'installation complète..."
    echo ""
    ./install-taskprint.sh
}

# Affichage des informations de fin
show_completion() {
    local ip_address=$(hostname -I | awk '{print $1}')
    
    print_header
    echo -e "${GREEN}🎉 Installation TaskPrint Terminée avec Succès ! 🎉${NC}"
    echo ""
    echo -e "${CYAN}📍 Accès à votre TaskPrint:${NC}"
    echo -e "   🏠 Local:    ${YELLOW}http://localhost${NC}"
    echo -e "   🌐 Réseau:   ${YELLOW}http://$ip_address${NC}"
    echo ""
    echo -e "${CYAN}📱 Depuis vos appareils mobiles:${NC}"
    echo -e "   📱 Smartphone: Ouvrir ${YELLOW}http://$ip_address${NC} dans le navigateur"
    echo -e "   📱 Ajouter à l'écran d'accueil pour une expérience app native"
    echo ""
    echo -e "${CYAN}🛠️  Gestion du service:${NC}"
    echo -e "   ▶️  Démarrer:    ${YELLOW}sudo systemctl start taskprint${NC}"
    echo -e "   ⏹️  Arrêter:     ${YELLOW}sudo systemctl stop taskprint${NC}"
    echo -e "   🔄 Redémarrer:  ${YELLOW}sudo systemctl restart taskprint${NC}"
    echo -e "   📊 Status:      ${YELLOW}sudo systemctl status taskprint${NC}"
    echo ""
    echo -e "${CYAN}📋 Dossiers importants:${NC}"
    echo -e "   📁 Installation: ${YELLOW}$INSTALL_DIR${NC}"
    echo -e "   💾 Données:      ${YELLOW}$INSTALL_DIR/data${NC}"
    echo -e "   🖼️  Images:       ${YELLOW}$INSTALL_DIR/app/uploads${NC}"
    echo -e "   📝 Logs:         ${YELLOW}$INSTALL_DIR/logs${NC}"
    echo -e "   🔄 Sauvegardes:  ${YELLOW}$INSTALL_DIR/backups${NC}"
    echo ""
    echo -e "${CYAN}🔧 Scripts utiles:${NC}"
    echo -e "   💾 Sauvegarde:   ${YELLOW}$INSTALL_DIR/backup-taskprint.sh${NC}"
    echo -e "   📊 Monitoring:   ${YELLOW}$INSTALL_DIR/monitor-taskprint.sh${NC}"
    echo -e "   🚀 Mise à jour:  ${YELLOW}$INSTALL_DIR/update-taskprint.sh${NC}"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   📖 GitHub:       ${YELLOW}https://github.com/polbourgui/taskprint${NC}"
    echo -e "   🐛 Issues:       ${YELLOW}https://github.com/polbourgui/taskprint/issues${NC}"
    echo -e "   💬 Discussions:  ${YELLOW}https://github.com/polbourgui/taskprint/discussions${NC}"
    echo ""
    echo -e "${GREEN}✨ Fonctionnalités disponibles:${NC}"
    echo -e "   📝 Gestion de tâches avec priorités"
    echo -e "   📷 Prise de photo depuis mobile"
    echo -e "   ✏️  Annotations avancées sur images"
    echo -e "   🗜️  Compression automatique"
    echo -e "   🖨️  Impression thermique"
    echo -e "   💾 Synchronisation multi-device"
    echo -e "   🔄 Sauvegardes automatiques"
    echo ""
    echo -e "${PURPLE}🎯 Profitez de votre nouveau système de productivité !${NC}"
    echo ""
}

# Gestion des erreurs
handle_error() {
    print_error "Une erreur est survenue durant l'installation"
    print_info "Logs d'erreur sauvegardés dans: /tmp/taskprint-install-error.log"
    
    # Sauvegarde des logs d'erreur
    {
        echo "=== TaskPrint Installation Error Log ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "System: $(uname -a)"
        echo "Error occurred in function: ${1:-unknown}"
        echo "Exit code: $?"
        echo ""
        echo "=== Environment Variables ==="
        env | grep -E "(HOME|USER|PWD|PATH)" || true
        echo ""
        echo "=== Disk Space ==="
        df -h || true
        echo ""
        echo "=== Memory ==="
        free -h || true
        echo ""
        echo "=== Last Commands ==="
        history | tail -10 || true
    } > /tmp/taskprint-install-error.log
    
    print_info "Vous pouvez:"
    print_info "1. Consulter les logs: cat /tmp/taskprint-install-error.log"
    print_info "2. Signaler le problème: https://github.com/polbourgui/taskprint/issues"
    print_info "3. Rejoindre les discussions: https://github.com/polbourgui/taskprint/discussions"
    
    exit 1
}

# Configuration des traps pour la gestion d'erreur
trap 'handle_error "${FUNCNAME[0]}"' ERR

# Menu interactif
show_menu() {
    print_header
    echo -e "${CYAN}🚀 Bienvenue dans l'installateur TaskPrint !${NC}"
    echo ""
    echo -e "${YELLOW}TaskPrint est un gestionnaire de tâches moderne conçu pour votre Home Lab.${NC}"
    echo -e "${YELLOW}Il offre une interface web accessible depuis tous vos appareils avec${NC}"
    echo -e "${YELLOW}des fonctionnalités avancées d'annotation d'images et d'impression thermique.${NC}"
    echo ""
    echo -e "${CYAN}📋 Que souhaitez-vous faire ?${NC}"
    echo ""
    echo -e "  ${GREEN}1)${NC} 🚀 Installation complète automatique (Recommandé)"
    echo -e "  ${GREEN}2)${NC} 🔧 Installation personnalisée"
    echo -e "  ${GREEN}3)${NC} 📊 Vérifier les prérequis seulement"
    echo -e "  ${GREEN}4)${NC} 📥 Télécharger le code source seulement"
    echo -e "  ${GREEN}5)${NC} ❓ Afficher les informations système"
    echo -e "  ${GREEN}6)${NC} 🆘 Aide et support"
    echo -e "  ${GREEN}0)${NC} ❌ Quitter"
    echo ""
    read -p "Votre choix (0-6): " choice
    
    case $choice in
        1)
            automatic_installation
            ;;
        2)
            custom_installation
            ;;
        3)
            check_prerequisites_only
            ;;
        4)
            download_only
            ;;
        5)
            show_system_info
            ;;
        6)
            show_help
            ;;
        0)
            print_info "Au revoir ! 👋"
            exit 0
            ;;
        *)
            print_error "Choix invalide. Veuillez choisir entre 0 et 6."
            sleep 2
            show_menu
            ;;
    esac
}

# Installation automatique complète
automatic_installation() {
    print_step "🚀 Installation automatique de TaskPrint"
    echo ""
    print_info "Cette installation va:"
    print_info "✅ Vérifier votre système"
    print_info "✅ Installer Docker et les dépendances"
    print_info "✅ Télécharger TaskPrint depuis GitHub"
    print_info "✅ Configurer le service systemd"
    print_info "✅ Démarrer TaskPrint automatiquement"
    echo ""
    read -p "Continuer avec l'installation automatique ? (oui/non): " confirm
    if [[ ! "$confirm" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        show_menu
        return
    fi
    
    check_environment
    detect_hardware
    install_prerequisites
    download_source
    run_main_installer
    show_completion
}

# Installation personnalisée
custom_installation() {
    print_step "🔧 Installation personnalisée"
    echo ""
    
    # Options personnalisées
    echo -e "${CYAN}Configuration personnalisée:${NC}"
    echo ""
    
    # Port personnalisé
    read -p "Port d'écoute (défaut: 80): " custom_port
    custom_port=${custom_port:-80}
    
    # Dossier d'installation personnalisé
    read -p "Dossier d'installation (défaut: $INSTALL_DIR): " custom_dir
    if [[ ! -z "$custom_dir" ]]; then
        INSTALL_DIR="$custom_dir"
    fi
    
    # Installation SSL
    read -p "Configurer HTTPS/SSL ? (oui/non): " ssl_config
    
    # Mot de passe admin
    read -p "Configurer une authentification ? (oui/non): " auth_config
    if [[ "$auth_config" =~ ^([oO][uU][iI]|[yY][eE][sS])$ ]]; then
        read -s -p "Mot de passe admin: " admin_password
        echo ""
    fi
    
    print_info "Configuration personnalisée enregistrée"
    
    # Exporter les variables pour le script principal
    export TASKPRINT_PORT="$custom_port"
    export TASKPRINT_INSTALL_DIR="$INSTALL_DIR"
    export TASKPRINT_SSL="$ssl_config"
    export TASKPRINT_AUTH="$auth_config"
    export TASKPRINT_ADMIN_PASSWORD="$admin_password"
    
    check_environment
    detect_hardware
    install_prerequisites
    download_source
    run_main_installer
    show_completion
}

# Vérification des prérequis seulement
check_prerequisites_only() {
    print_step "📊 Vérification des prérequis système"
    echo ""
    
    check_environment
    detect_hardware
    
    print_info "Vérification des outils..."
    
    # Vérifier Git
    if command -v git &> /dev/null; then
        local git_version=$(git --version | cut -d' ' -f3)
        print_success "Git installé (version $git_version)"
    else
        print_warning "Git non installé"
    fi
    
    # Vérifier Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        print_success "Docker installé (version $docker_version)"
        
        # Vérifier les permissions Docker
        if docker ps &> /dev/null; then
            print_success "Permissions Docker OK"
        else
            print_warning "Permissions Docker insuffisantes"
            print_info "Exécutez: sudo usermod -aG docker \$USER && newgrp docker"
        fi
    else
        print_warning "Docker non installé"
    fi
    
    # Vérifier Docker Compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        print_success "Docker Compose installé (version $compose_version)"
    else
        print_warning "Docker Compose non installé"
    fi
    
    # Vérifier les ports
    print_info "Vérification des ports..."
    if ss -tuln | grep -q ":80 "; then
        print_warning "Port 80 déjà utilisé"
    else
        print_success "Port 80 disponible"
    fi
    
    if ss -tuln | grep -q ":3000 "; then
        print_warning "Port 3000 déjà utilisé"
    else
        print_success "Port 3000 disponible"
    fi
    
    echo ""
    print_info "Vérification terminée. Appuyez sur Entrée pour revenir au menu..."
    read
    show_menu
}

# Téléchargement seulement
download_only() {
    print_step "📥 Téléchargement du code source TaskPrint"
    echo ""
    
    check_environment
    install_prerequisites
    download_source
    
    print_success "Code source téléchargé dans: $INSTALL_DIR"
    print_info "Pour installer manuellement:"
    print_info "  cd $INSTALL_DIR"
    print_info "  chmod +x install-taskprint.sh"
    print_info "  ./install-taskprint.sh"
    echo ""
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_menu
}

# Informations système détaillées
show_system_info() {
    print_step "💻 Informations système détaillées"
    echo ""
    
    echo -e "${CYAN}🖥️  Système d'exploitation:${NC}"
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo "   Nom: $PRETTY_NAME"
        echo "   Version: $VERSION"
        echo "   ID: $ID"
    fi
    
    echo ""
    echo -e "${CYAN}💾 Processeur et mémoire:${NC}"
    echo "   CPU: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)"
    echo "   Cœurs: $(nproc) cœurs"
    echo "   Architecture: $(uname -m)"
    echo "   RAM totale: $(free -h | grep Mem | awk '{print $2}')"
    echo "   RAM disponible: $(free -h | grep Mem | awk '{print $7}')"
    
    echo ""
    echo -e "${CYAN}💽 Stockage:${NC}"
    df -h | grep -E "(Filesystem|/dev/)" | head -10
    
    echo ""
    echo -e "${CYAN}🌐 Réseau:${NC}"
    echo "   IP locale: $(hostname -I | awk '{print $1}')"
    echo "   Nom d'hôte: $(hostname)"
    echo "   Interface: $(ip route | grep default | awk '{print $5}' | head -1)"
    
    echo ""
    echo -e "${CYAN}🐳 Docker (si installé):${NC}"
    if command -v docker &> /dev/null; then
        echo "   Version Docker: $(docker --version)"
        if command -v docker-compose &> /dev/null; then
            echo "   Version Compose: $(docker-compose --version)"
        fi
        echo "   Conteneurs actifs: $(docker ps -q | wc -l 2>/dev/null || echo "0")"
        echo "   Images: $(docker images -q | wc -l 2>/dev/null || echo "0")"
    else
        echo "   Docker non installé"
    fi
    
    echo ""
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_menu
}

# Aide et support
show_help() {
    print_step "🆘 Aide et support TaskPrint"
    echo ""
    
    echo -e "${CYAN}📖 Documentation et ressources:${NC}"
    echo "   🌐 Site du projet: https://github.com/polbourgui/taskprint"
    echo "   📚 Wiki complet: https://github.com/polbourgui/taskprint/wiki"
    echo "   🎥 Tutoriels vidéo: https://github.com/polbourgui/taskprint/wiki/tutorials"
    echo "   📋 FAQ: https://github.com/polbourgui/taskprint/wiki/faq"
    echo ""
    
    echo -e "${CYAN}💬 Communauté et support:${NC}"
    echo "   💭 Discussions: https://github.com/polbourgui/taskprint/discussions"
    echo "   🐛 Signaler un bug: https://github.com/polbourgui/taskprint/issues"
    echo "   📧 Contact direct: pol@taskprint.dev"
    echo ""
    
    echo -e "${CYAN}🔧 Dépannage rapide:${NC}"
    echo "   1. Vérifiez que votre système est Ubuntu/Debian"
    echo "   2. Assurez-vous d'avoir les privilèges sudo"
    echo "   3. Vérifiez votre connexion Internet"
    echo "   4. Libérez au moins 2GB d'espace disque"
    echo "   5. Fermez les applications utilisant les ports 80/3000"
    echo ""
    
    echo -e "${CYAN}📋 Commandes utiles après installation:${NC}"
    echo "   sudo systemctl status taskprint    # Vérifier le service"
    echo "   docker-compose logs -f             # Voir les logs"
    echo "   ~/taskprint-server/monitor-taskprint.sh  # Diagnostic"
    echo ""
    
    echo -e "${CYAN}🚀 Prochaines étapes après installation:${NC}"
    echo "   1. Accéder à http://VOTRE_IP depuis un navigateur"
    echo "   2. Créer vos premières tâches"
    echo "   3. Tester la prise de photo depuis mobile"
    echo "   4. Configurer votre imprimante thermique"
    echo "   5. Ajouter TaskPrint à l'écran d'accueil mobile"
    echo ""
    
    print_info "Appuyez sur Entrée pour revenir au menu..."
    read
    show_menu
}

# Point d'entrée principal
main() {
    # Gestion des arguments de ligne de commande
    case "${1:-}" in
        --auto|--automatic)
            print_header
            automatic_installation
            ;;
        --custom)
            print_header
            custom_installation
            ;;
        --check|--prerequisites)
            print_header
            check_prerequisites_only
            ;;
        --download|--source)
            print_header
            download_only
            ;;
        --info|--system)
            print_header
            show_system_info
            ;;
        --help|-h)
            print_header
            show_help
            ;;
        --version|-v)
            echo "TaskPrint Quick Installer v1.0"
            echo "Repository: https://github.com/polbourgui/taskprint"
            echo "Author: Pol Bourguignon"
            ;;
        *)
            show_menu
            ;;
    esac
}

# Vérification si le script est exécuté directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
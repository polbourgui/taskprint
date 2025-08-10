# 📋 TaskPrint - Gestionnaire de Tâches pour Home Lab

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue)](https://www.docker.com/)
[![NUC Intel](https://img.shields.io/badge/NUC%20Intel-Compatible-green)](https://www.intel.com/nuc)
[![Node.js](https://img.shields.io/badge/Node.js-18+-brightgreen)](https://nodejs.org/)

> 🚀 **Gestionnaire de tâches moderne avec impression thermique, annotations d'images et interface mobile, optimisé pour NUC Intel Home Lab**

![TaskPrint Demo](https://raw.githubusercontent.com/polbourgui/taskprint/main/docs/images/demo.gif)

## ✨ Fonctionnalités

### 📝 **Gestion de Tâches Avancée**
- ✅ Création de tâches avec priorités (Haute/Moyenne/Basse)
- 🏷️ Catégories personnalisables (Travail, Personnel, Urgent, etc.)
- 📝 Descriptions détaillées et notes
- ✔️ Système de sélection pour impression groupée

### 📷 **Gestion d'Images Professionnelle**
- 📱 **Prise de photo directe** depuis smartphone/webcam
- 🗜️ **Compression automatique** intelligente (réduction jusqu'à 80%)
- ✏️ **Annotations avancées** : stylo, formes, texte, couleurs
- 🖼️ **Prévisualisation** et zoom modal

### 🖨️ **Impression Thermique Intégrée**
- 🎯 Format optimisé pour imprimantes ESC/POS
- 📋 Aperçu avant impression
- 🔄 Impression de toutes les tâches ou sélection
- 📄 Support QR codes et logos

### 🏠 **Home Lab Ready**
- 🐳 **Déploiement Docker** complet
- 🔧 **Service systemd** automatique
- 📊 **Monitoring** et health checks
- 💾 **Sauvegardes** automatisées
- 🌐 **Accès réseau local** multi-device

## 🚀 Installation Rapide

### **Installation en Une Commande**

```bash
# Télécharger et installer sur NUC Intel
curl -fsSL https://raw.githubusercontent.com/polbourgui/taskprint/main/install-taskprint.sh | bash
```

### **Installation Manuelle**

```bash
# Cloner le repository
git clone https://github.com/polbourgui/taskprint.git
cd taskprint

# Rendre le script exécutable
chmod +x install-taskprint.sh

# Lancer l'installation
./install-taskprint.sh
```

### **Accès immédiat**

Après installation, accédez à TaskPrint via :
- **Local** : `http://localhost`
- **Réseau** : `http://IP_DE_VOTRE_NUC`

## 📱 Interface Utilisateur

### **Desktop & Mobile**

<div align="center">

| 💻 Desktop | 📱 Mobile | 🖼️ Annotations |
|------------|-----------|-----------------|
| ![Desktop](docs/images/desktop.png) | ![Mobile](docs/images/mobile.png) | ![Annotations](docs/images/annotations.png) |

</div>

### **Fonctionnalités Tactiles**
- ✏️ **Dessiner** à la souris ou au doigt
- 🎨 **Palette de couleurs** intuitive
- 📐 **Outils géométriques** (rectangles, cercles, flèches)
- 💬 **Ajout de texte** avec positionnement libre

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│              NUC Intel                  │
│  ┌─────────────────────────────────┐    │
│  │         Ubuntu Server           │    │
│  │  ┌─────────────────────────┐    │    │
│  │  │      Docker              │    │    │
│  │  │  ┌─────────────────┐    │    │    │
│  │  │  │   TaskPrint     │    │    │    │
│  │  │  │   (Node.js)     │    │    │    │
│  │  │  │   Port 3000     │    │    │    │
│  │  │  └─────────────────┘    │    │    │
│  │  │  ┌─────────────────┐    │    │    │
│  │  │  │     Nginx       │    │    │    │
│  │  │  │   Port 80/443   │    │    │    │
│  │  │  └─────────────────┘    │    │    │
│  │  └─────────────────────────┘    │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
         │
         │ Réseau Local (192.168.1.x)
         │
    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │📱 Phone │  │💻 PC    │  │📱Tablet │
    └─────────┘  └─────────┘  └─────────┘
```

## 🛠️ Configuration Technique

### **Prérequis**
- 🖥️ **NUC Intel** (ou PC compatible)
- 🐧 **Ubuntu 20.04+** / Debian 11+
- 🐳 **Docker** & Docker Compose
- 🌐 **Réseau local** configuré
- 💾 **2GB RAM** minimum, 4GB recommandé

### **Ports Utilisés**
- **80** : Interface web principale
- **443** : HTTPS (optionnel)
- **3000** : API Node.js (interne)

### **Stockage**
- **Configuration** : `~/taskprint-server/`
- **Données** : `~/taskprint-server/data/`
- **Images** : `~/taskprint-server/app/uploads/`
- **Logs** : `~/taskprint-server/logs/`
- **Sauvegardes** : `~/taskprint-server/backups/`

## 🎛️ Gestion et Maintenance

### **Commandes Essentielles**

```bash
# Status du service
sudo systemctl status taskprint

# Redémarrer
sudo systemctl restart taskprint

# Voir les logs
docker-compose -f ~/taskprint-server/docker-compose.yml logs -f

# Sauvegarde manuelle
~/taskprint-server/backup-taskprint.sh

# Monitoring
~/taskprint-server/monitor-taskprint.sh

# Mise à jour
~/taskprint-server/update-taskprint.sh
```

### **API REST**

| Endpoint | Méthode | Description |
|----------|---------|-------------|
| `/health` | GET | État du serveur |
| `/api/info` | GET | Informations système |
| `/api/tasks` | GET | Liste des tâches |
| `/api/tasks` | POST | Sauvegarder tâches |
| `/api/print` | POST | Lancer impression |

### **Exemples d'Utilisation API**

```bash
# Vérifier la santé du serveur
curl http://localhost/health

# Récupérer les tâches
curl http://localhost/api/tasks

# Ajouter une tâche
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -d '[{"title":"Ma tâche","priority":"high"}]'
```

## 🖨️ Impression Thermique

### **Imprimantes Compatibles**
- ✅ **Epson TM-T20II** (USB/Ethernet)
- ✅ **Star TSP143III** (USB/Bluetooth)
- ✅ **Zebra GC420d** (USB/Ethernet)
- ✅ **Brother QL-800** (USB)
- ✅ **Toutes imprimantes ESC/POS**

### **Configuration Impression**

```javascript
// Exemple d'intégration ESC/POS
const escpos = require('escpos');
const device = new escpos.USB();
const printer = new escpos.Printer(device);

device.open(() => {
    printer
        .font('a').align('ct').style('bu')
        .size(1, 1).text('MES TÂCHES')
        .text('==================')
        .align('lt').text(taskContent)
        .feed(3).cut().close();
});
```

## 📊 Monitoring et Analytics

### **Métriques Disponibles**
- 📈 **Uptime** serveur
- 📝 **Nombre de tâches** créées
- 🖼️ **Images uploadées** et traitées
- 🖨️ **Impressions** réalisées
- 💾 **Utilisation disque**
- 🔄 **Performance** API

### **Dashboards**
- 🎛️ **Interface web** intégrée
- 📊 **Grafana** (optionnel)
- 🔍 **Logs centralisés**
- ⚠️ **Alertes** automatiques

## 🔒 Sécurité

### **Bonnes Pratiques Implémentées**
- 🛡️ **Isolation Docker** containers
- 🔐 **Headers sécurisés** (Helmet.js)
- 🌐 **Accès réseau local** uniquement
- 📋 **Logs d'audit** complets
- 🔄 **Sauvegardes chiffrées** (optionnel)
- 🚫 **Pas d'exposition Internet** par défaut

### **Configuration Firewall**

```bash
# Limiter l'accès au réseau local
sudo ufw enable
sudo ufw allow from 192.168.0.0/16 to any port 80
sudo ufw allow from 10.0.0.0/8 to any port 80
```

## 🚀 Développement

### **Setup Développement**

```bash
# Cloner et setup
git clone https://github.com/polbourgui/taskprint.git
cd taskprint

# Installer les dépendances
npm install

# Mode développement
npm run dev

# Tests
npm test
npm run lint
```

### **Structure du Projet**

```
taskprint/
├── 📁 app/
│   ├── 📄 server.js           # Serveur Node.js principal
│   ├── 📄 package.json        # Dépendances
│   └── 📁 public/
│       └── 📄 index.html      # Interface utilisateur
├── 📁 nginx/
│   └── 📄 nginx.conf          # Configuration reverse proxy
├── 📁 docs/                   # Documentation
├── 📄 docker-compose.yml      # Orchestration Docker
├── 📄 install-taskprint.sh    # Script d'installation
└── 📄 README.md              # Ce fichier
```

## 🎯 Cas d'Usage

### **👨‍💼 Professionnel**
- 📋 **Listes de tâches** équipe
- 🐛 **Documentation bugs** avec screenshots
- 📊 **Rapports** quotidiens imprimés
- ✅ **Checklists qualité** avec photos

### **🏠 Personnel**
- 🛒 **Listes de courses** synchronisées
- 🔧 **Tâches bricolage** avec annotations
- 📅 **Planning familial** imprimable
- 📸 **Suivi projets** avec photos avant/après

### **🏢 Entreprise**
- 🔧 **Tickets maintenance** avec images
- ✅ **Validation qualité** documentée
- 📋 **Rapports intervention** imprimables
- 📈 **Workflow** tracé et archivé

## 📈 Performances

### **Benchmarks NUC Intel**
- ⚡ **Temps de réponse** : < 100ms (réseau local)
- 📱 **Utilisateurs simultanés** : 10+ sans problème
- 🖼️ **Traitement d'images** : 2-3 secondes (compression + annotation)
- 💾 **Stockage** : Illimité (dépend du SSD NUC)
- 🔄 **Uptime** : 99.9% (redémarrage automatique)

## 🗺️ Roadmap

### **Version 2.0 - Intelligence** 🤖
- [ ] OCR pour extraction de texte des images
- [ ] Reconnaissance vocale pour dictée
- [ ] IA pour catégorisation automatique
- [ ] Prédiction durées de tâches

### **Version 2.1 - Collaboration** 👥
- [ ] Multi-utilisateurs avec permissions
- [ ] Commentaires et discussions
- [ ] Assignation et workflow
- [ ] Notifications push

### **Version 2.2 - Intégrations** 🔗
- [ ] API publique pour développeurs
- [ ] Plugin Home Assistant
- [ ] Webhooks et automatisation
- [ ] App mobile native

## 🤝 Contribution

Les contributions sont les bienvenues ! Voici comment contribuer :

1. 🍴 **Fork** le projet
2. 🌿 **Créer** une branche (`git checkout -b feature/AmazingFeature`)
3. 💾 **Commit** vos changements (`git commit -m 'Add AmazingFeature'`)
4. 📤 **Push** vers la branche (`git push origin feature/AmazingFeature`)
5. 🔀 **Ouvrir** une Pull Request

### **Types de Contributions**
- 🐛 **Bug fixes** et corrections
- ✨ **Nouvelles fonctionnalités**
- 📚 **Documentation** et tutorials
- 🧪 **Tests** et amélioration qualité
- 🎨 **Interface** et UX/UI
- 🔧 **Configuration** et déploiement

## 📝 License

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 💬 Support

### **Documentation**
- 📖 [Wiki complet](https://github.com/polbourgui/taskprint/wiki)
- 🎥 [Vidéos tutorials](https://github.com/polbourgui/taskprint/wiki/tutorials)
- 📋 [FAQ](https://github.com/polbourgui/taskprint/wiki/faq)

### **Communauté**
- 💬 [GitHub Discussions](https://github.com/polbourgui/taskprint/discussions)
- 🐛 [Issues GitHub](https://github.com/polbourgui/taskprint/issues)
- 📧 Email : pol@taskprint.dev

### **Aide Rapide**

```bash
# Diagnostic automatique
~/taskprint-server/monitor-taskprint.sh

# Logs détaillés
journalctl -xeu taskprint.service

# Reset complet (dernier recours)
~/taskprint-server/update-taskprint.sh --reset
```

---

<div align="center">

**⭐ Si TaskPrint vous aide dans votre productivité, n'hésitez pas à mettre une étoile au projet ! ⭐**

Made with ❤️ by [Pol Bourguignon](https://github.com/polbourgui)

🏠 **Perfect for Home Lab** • 🖨️ **Thermal Printing Ready** • 📱 **Mobile First**

</div>
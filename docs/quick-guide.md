# 🚀 Guide Rapide - TaskPrint sur NUC Intel

## 📥 Installation en 5 minutes

### **1. Téléchargement et exécution**

```bash
# Télécharger le script d'installation
wget https://raw.githubusercontent.com/polbourgui/taskprint/main/install-taskprint.sh

# Rendre exécutable
chmod +x install-taskprint.sh

# Lancer l'installation
./install-taskprint.sh
```

### **2. Après redémarrage (si nécessaire)**

```bash
# Si le script demande un redémarrage
sudo reboot

# Après redémarrage, finaliser l'installation
./install-taskprint.sh --start-only
```

## 🌐 Accès instantané

### **Depuis vos appareils :**

| Appareil | URL d'accès | Action |
|----------|-------------|--------|
| 📱 **Smartphone** | `http://192.168.1.100` | Ouvrir dans le navigateur |
| 💻 **Ordinateur** | `http://192.168.1.100` | Marquer en favori |
| 📱 **Application mobile** | Ajouter à l'écran d'accueil | PWA native |

> **💡 Astuce :** Remplacez `192.168.1.100` par l'IP réelle de votre NUC

## ⚡ Commandes essentielles

### **Gestion du service**

```bash
# Status du service
sudo systemctl status taskprint

# Redémarrer
sudo systemctl restart taskprint

# Arrêter
sudo systemctl stop taskprint

# Démarrer
sudo systemctl start taskprint

# Désactiver au démarrage
sudo systemctl disable taskprint
```

### **Monitoring Docker**

```bash
# Voir l'état des conteneurs
cd ~/taskprint-server
docker-compose ps

# Logs en temps réel
docker-compose logs -f

# Logs d'un service spécifique
docker-compose logs -f taskprint-app
docker-compose logs -f taskprint-nginx

# Redémarrer un service
docker-compose restart taskprint-app
```

## 🛠️ Maintenance quotidienne

### **Scripts automatiques disponibles**

```bash
# Sauvegarde manuelle
~/taskprint-server/backup-taskprint.sh

# Vérification santé
~/taskprint-server/monitor-taskprint.sh

# Mise à jour
~/taskprint-server/update-taskprint.sh
```

### **Vérifications rapides**

```bash
# Test de connectivité
curl http://localhost/health

# Espace disque
df -h

# Mémoire utilisée
free -h

# Processus Docker
docker stats --no-stream
```

## 📊 Surveillance

### **URLs de monitoring**

| Endpoint | Description | Exemple |
|----------|-------------|---------|
| `/health` | État du serveur | `{"status":"healthy"}` |
| `/api/info` | Infos système | Uptime, tâches, uploads |
| `/api/tasks` | Liste des tâches | JSON des tâches |

### **Logs importants**

```bash
# Logs du serveur Node.js
cat ~/taskprint-server/logs/server.log

# Logs d'impression
cat ~/taskprint-server/logs/printing.log

# Logs de monitoring
cat ~/taskprint-server/logs/monitor.log

# Logs Nginx
sudo tail -f /var/log/nginx/taskprint_access.log
```

## 🔧 Personnalisation

### **Changer le port d'écoute**

```bash
# Éditer docker-compose.yml
nano ~/taskprint-server/docker-compose.yml

# Modifier la ligne ports de nginx:
ports:
  - "8080:80"  # Au lieu de "80:80"

# Redémarrer
docker-compose restart
```

### **Configurer HTTPS (SSL)**

```bash
# Installer Certbot
sudo apt install certbot python3-certbot-nginx

# Obtenir un certificat (domaine requis)
sudo certbot --nginx -d votre-domaine.com

# Renouvellement automatique
sudo crontab -e
# Ajouter : 0 12 * * * /usr/bin/certbot renew --quiet
```

### **Ajouter une authentification**

Modifier `~/taskprint-server/nginx/nginx.conf` :

```nginx
# Ajouter dans le bloc server
auth_basic "TaskPrint Access";
auth_basic_user_file /etc/nginx/.htpasswd;

# Créer le fichier de mots de passe
sudo htpasswd -c /etc/nginx/.htpasswd admin
```

## 🚨 Dépannage

### **Problèmes courants**

| Problème | Solution | Commande |
|----------|----------|----------|
| Service ne démarre pas | Vérifier Docker | `sudo systemctl status docker` |
| Port 80 occupé | Changer le port | Modifier `docker-compose.yml` |
| Conteneur crash | Voir les logs | `docker-compose logs` |
| Pas d'accès réseau | Vérifier firewall | `sudo ufw status` |
| Manque d'espace | Nettoyer Docker | `docker system prune -a` |

### **Diagnostic complet**

```bash
#!/bin/bash
# Script de diagnostic TaskPrint

echo "=== DIAGNOSTIC TASKPRINT ==="
echo "Date: $(date)"
echo ""

echo "1. Status système:"
systemctl status taskprint --no-pager
echo ""

echo "2. Status Docker:"
docker-compose -f ~/taskprint-server/docker-compose.yml ps
echo ""

echo "3. Connectivité HTTP:"
curl -I http://localhost/health 2>/dev/null || echo "❌ HTTP inaccessible"
echo ""

echo "4. Espace disque:"
df -h / | tail -1
echo ""

echo "5. Mémoire:"
free -h
echo ""

echo "6. Processus Docker:"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo ""

echo "7. Derniers logs (5 lignes):"
docker-compose -f ~/taskprint-server/docker-compose.yml logs --tail=5
```

### **Reset complet**

```bash
# Arrêter tous les services
sudo systemctl stop taskprint
cd ~/taskprint-server
docker-compose down -v

# Sauvegarder les données
cp -r data data_backup_$(date +%Y%m%d)

# Supprimer et reconstruire
docker-compose down --rmi all
docker-compose build --no-cache
docker-compose up -d

# Redémarrer le service système
sudo systemctl start taskprint
```

## 🔒 Sécurité

### **Bonnes pratiques**

1. **Firewall** - Limiter l'accès au réseau local
```bash
# Configurer UFW
sudo ufw enable
sudo ufw allow from 192.168.0.0/16 to any port 80
```

2. **Mises à jour système**
```bash
# Auto-updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

3. **Surveillance réseau**
```bash
# Installer fail2ban
sudo apt install fail2ban
```

### **Sauvegarde hors site**

```bash
# Script de sauvegarde vers un NAS/Cloud
#!/bin/bash
BACKUP_FILE="taskprint_$(date +%Y%m%d).tar.gz"
tar -czf "/tmp/$BACKUP_FILE" -C ~/taskprint-server data app/uploads

# Exemples d'envoi:
# rsync "/tmp/$BACKUP_FILE" user@nas:/backups/
# rclone copy "/tmp/$BACKUP_FILE" mycloud:backups/
# scp "/tmp/$BACKUP_FILE" user@remote:/backups/
```

## 📱 Intégration mobile avancée

### **Raccourcis iOS (Siri)**

1. Ouvrir l'app **Raccourcis**
2. Créer un nouveau raccourci
3. Ajouter action **Ouvrir l'URL**
4. URL: `http://IP_DU_NUC/api/tasks`
5. Nommer: "Mes tâches TaskPrint"

### **Widget Android**

1. Ajouter widget navigateur
2. URL: `http://IP_DU_NUC`
3. Taille: 4x2 ou plus grand

### **Notifications push (bonus)**

Ajouter dans `server.js` :

```javascript
// Notifications via webhook
app.post('/api/notify', (req, res) => {
    const { message, urgency } = req.body;
    
    // Exemple avec Discord webhook
    const webhook_url = process.env.DISCORD_WEBHOOK;
    if (webhook_url) {
        fetch(webhook_url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                content: `🔔 TaskPrint: ${message}`,
                username: 'TaskPrint Bot'
            })
        });
    }
    
    res.json({ sent: true });
});
```

## 📈 Optimisation performances

### **Pour NUC avec SSD**

```bash
# Optimisations système
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# Optimisations Docker
# Ajouter dans docker-compose.yml:
tmpfs:
  - /tmp
  - /var/tmp
```

### **Monitoring avancé avec Prometheus**

```yaml
# Ajouter dans docker-compose.yml
services:
  prometheus:
    image: prom/prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
```

## 🎯 Cas d'usage avancés

### **Intégration imprimante Brother**

```bash
# Installation drivers Brother
wget https://download.brother.com/welcome/dlf006893/linux-brprinter-installer-2.2.3-1.gz
gunzip linux-brprinter-installer-2.2.3-1.gz
sudo bash linux-brprinter-installer-2.2.3-1 HL-L2350DW

# Test d'impression
echo "Test TaskPrint" | lp -d Brother_HL_L2350DW_series
```

### **API externe (Google Calendar)**

```javascript
// Intégration Google Calendar dans server.js
app.post('/api/sync-calendar', async (req, res) => {
    // Code d'intégration Google Calendar API
    // Convertir tâches en événements calendrier
});
```

### **Backup automatique vers GitHub**

```bash
# Script de backup Git
#!/bin/bash
cd ~/taskprint-server
git add data/
git commit -m "Auto backup $(date)"
git push origin main
```

## 🆘 Support et communauté

### **Resources utiles**

- 📖 **Documentation complète** : [Wiki TaskPrint](https://github.com/your-repo/wiki)
- 💬 **Forum communauté** : [Discord TaskPrint](https://discord.gg/taskprint)
- 🐛 **Signaler un bug** : [GitHub Issues](https://github.com/your-repo/issues)
- 📧 **Contact** : support@taskprint.com

### **Contribution**

```bash
# Fork et développement
git clone https://github.com/polbourgui/taskprint.git
cd taskprint
npm install
npm run dev

# Tests
npm test
npm run lint
```

---

## 🎉 Félicitations !

Votre NUC Intel est maintenant un serveur TaskPrint professionnel !

**Prochaines étapes suggérées :**
1. ✅ Ajouter quelques tâches de test
2. ✅ Tester l'impression depuis mobile
3. ✅ Configurer les sauvegardes automatiques  
4. ✅ Partager l'accès avec votre famille/équipe
5. ✅ Explorer les intégrations avancées

**Profitez de votre nouveau système de productivité ! 🚀**
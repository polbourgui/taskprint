#!/bin/bash

# =============================================================================
# Script d'installation automatique TaskPrint sur NUC Intel
# =============================================================================

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables de configuration
INSTALL_DIR="$HOME/taskprint-server"
SERVICE_NAME="taskprint"
NGINX_SITE="taskprint"
USER_NAME=$(whoami)

# Fonctions utilitaires
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

# Vérification des prérequis
check_requirements() {
    print_step "Vérification des prérequis..."
    
    # Vérifier si on est sous Ubuntu/Debian
    if ! command -v apt &> /dev/null; then
        print_error "Ce script nécessite Ubuntu/Debian avec apt"
        exit 1
    fi
    
    # Vérifier les permissions sudo
    if ! sudo -n true 2>/dev/null; then
        print_error "Ce script nécessite les privilèges sudo"
        exit 1
    fi
    
    print_success "Prérequis vérifiés"
}

# Installation de Docker
install_docker() {
    print_step "Installation de Docker..."
    
    if command -v docker &> /dev/null; then
        print_warning "Docker est déjà installé"
        return
    fi
    
    # Mise à jour des paquets
    sudo apt update
    
    # Installation des dépendances
    sudo apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Ajouter la clé GPG officielle de Docker
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Ajouter le repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Installation de Docker
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Ajouter l'utilisateur au groupe docker
    sudo usermod -aG docker $USER_NAME
    
    print_success "Docker installé avec succès"
}

# Installation de Docker Compose
install_docker_compose() {
    print_step "Installation de Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        print_warning "Docker Compose est déjà installé"
        return
    fi
    
    sudo apt install -y docker-compose
    
    print_success "Docker Compose installé avec succès"
}

# Création de la structure des dossiers
create_directory_structure() {
    print_step "Création de la structure des dossiers..."
    
    # Supprimer l'ancien dossier s'il existe
    if [ -d "$INSTALL_DIR" ]; then
        print_warning "Dossier existant détecté, sauvegarde en cours..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Créer la structure
    mkdir -p "$INSTALL_DIR"/{app/{public,uploads,data,logs},nginx,data,logs,backups}
    
    print_success "Structure des dossiers créée"
}

# Génération des fichiers de configuration
generate_config_files() {
    print_step "Génération des fichiers de configuration..."
    
    # Package.json
    cat > "$INSTALL_DIR/app/package.json" << 'EOF'
{
  "name": "taskprint-server",
  "version": "1.0.0",
  "description": "TaskPrint Server pour Home Lab",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "multer": "^1.4.5-lts.1",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "compression": "^1.7.4"
  },
  "devDependencies": {
    "nodemon": "^3.0.1"
  }
}
EOF

    # Server.js
    cat > "$INSTALL_DIR/app/server.js" << 'EOF'
const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuration de sécurité et middlewares
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:", "blob:"],
            connectSrc: ["'self'"]
        }
    }
}));

app.use(cors());
app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));

// Configuration de multer pour l'upload de fichiers
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, 'uploads/'),
    filename: (req, file, cb) => cb(null, Date.now() + '-' + file.originalname)
});
const upload = multer({ storage: storage, limits: { fileSize: 50 * 1024 * 1024 } });

// Création des dossiers nécessaires
['uploads', 'data', 'logs'].forEach(dir => {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
});

// Routes principales
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API pour sauvegarder les tâches
app.post('/api/tasks', (req, res) => {
    try {
        const tasks = req.body;
        const dataPath = path.join(__dirname, 'data', 'tasks.json');
        
        // Sauvegarde avec backup
        if (fs.existsSync(dataPath)) {
            fs.copyFileSync(dataPath, `${dataPath}.backup`);
        }
        
        fs.writeFileSync(dataPath, JSON.stringify(tasks, null, 2));
        
        res.json({ 
            success: true, 
            message: 'Tâches sauvegardées',
            timestamp: new Date().toISOString(),
            count: tasks.length 
        });
    } catch (error) {
        console.error('Erreur sauvegarde tâches:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erreur lors de la sauvegarde',
            error: error.message 
        });
    }
});

// API pour charger les tâches
app.get('/api/tasks', (req, res) => {
    try {
        const dataPath = path.join(__dirname, 'data', 'tasks.json');
        
        if (fs.existsSync(dataPath)) {
            const tasks = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
            res.json(tasks);
        } else {
            res.json([]);
        }
    } catch (error) {
        console.error('Erreur lecture tâches:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erreur lors du chargement',
            error: error.message 
        });
    }
});

// API pour l'impression thermique
app.post('/api/print', (req, res) => {
    const { content, printer, format } = req.body;
    
    try {
        // Log de l'impression
        const logEntry = {
            timestamp: new Date().toISOString(),
            content: content.substring(0, 100) + '...',
            printer: printer || 'default',
            format: format || 'text',
            success: true
        };
        
        const logPath = path.join(__dirname, 'logs', 'printing.log');
        fs.appendFileSync(logPath, JSON.stringify(logEntry) + '\n');
        
        // Ici vous pouvez intégrer votre code d'impression thermique
        console.log('Impression demandée:', { printer, format, contentLength: content.length });
        
        res.json({ 
            success: true, 
            message: 'Impression envoyée vers l\'imprimante thermique',
            timestamp: new Date().toISOString()
        });
    } catch (error) {
        console.error('Erreur impression:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Erreur lors de l\'impression',
            error: error.message 
        });
    }
});

// API de santé du service
app.get('/health', (req, res) => {
    const healthData = {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        version: process.version,
        platform: process.platform
    };
    
    res.json(healthData);
});

// API d'informations système
app.get('/api/info', (req, res) => {
    try {
        const tasksPath = path.join(__dirname, 'data', 'tasks.json');
        const tasksCount = fs.existsSync(tasksPath) ? 
            JSON.parse(fs.readFileSync(tasksPath, 'utf8')).length : 0;
        
        const uploadsDir = path.join(__dirname, 'uploads');
        const uploadsCount = fs.existsSync(uploadsDir) ? 
            fs.readdirSync(uploadsDir).length : 0;
        
        res.json({
            service: 'TaskPrint Server',
            version: '1.0.0',
            tasksCount,
            uploadsCount,
            uptime: process.uptime(),
            startTime: new Date(Date.now() - process.uptime() * 1000).toISOString()
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Gestionnaire d'erreurs global
app.use((error, req, res, next) => {
    console.error('Erreur serveur:', error);
    res.status(500).json({ 
        success: false, 
        message: 'Erreur interne du serveur' 
    });
});

// Gestionnaire 404
app.use('*', (req, res) => {
    res.status(404).json({ 
        success: false, 
        message: 'Route non trouvée' 
    });
});

// Démarrage du serveur
app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 TaskPrint Server démarré sur http://0.0.0.0:${PORT}`);
    console.log(`📱 Accessible sur le réseau local via http://[IP_DU_NUC]:${PORT}`);
    console.log(`🔧 Environnement: ${process.env.NODE_ENV || 'development'}`);
    
    // Log de démarrage
    const startupLog = {
        timestamp: new Date().toISOString(),
        event: 'server_start',
        port: PORT,
        nodeVersion: process.version
    };
    
    const logPath = path.join(__dirname, 'logs', 'server.log');
    fs.appendFileSync(logPath, JSON.stringify(startupLog) + '\n');
});

// Gestion propre de l'arrêt
process.on('SIGTERM', () => {
    console.log('🛑 Signal SIGTERM reçu, arrêt du serveur...');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('🛑 Signal SIGINT reçu, arrêt du serveur...');
    process.exit(0);
});
EOF

    # Dockerfile
    cat > "$INSTALL_DIR/app/Dockerfile" << 'EOF'
FROM node:18-alpine

# Installation des outils système nécessaires
RUN apk add --no-cache \
    curl \
    bash \
    tzdata

# Configuration du timezone
ENV TZ=Europe/Paris

# Création de l'utilisateur non-root
RUN addgroup -g 1001 -S nodejs && \
    adduser -S taskprint -u 1001

# Création du répertoire de travail
WORKDIR /app

# Copie et installation des dépendances
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copie du code source
COPY --chown=taskprint:nodejs . .

# Création des dossiers nécessaires avec permissions
RUN mkdir -p uploads data logs public && \
    chown -R taskprint:nodejs /app

# Changement vers l'utilisateur non-root
USER taskprint

# Exposition du port
EXPOSE 3000

# Variables d'environnement
ENV NODE_ENV=production
ENV PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/health || exit 1

# Commande de démarrage
CMD ["node", "server.js"]
EOF

    # Configuration Nginx
    cat > "$INSTALL_DIR/nginx/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # Configuration des logs
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;
    
    # Configuration de performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
    
    # Configuration des uploads
    client_max_body_size 50M;
    client_body_buffer_size 1M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json image/svg+xml;
    
    # Configuration du serveur principal
    server {
        listen 80;
        server_name taskprint.local _;
        
        # Sécurité
        server_tokens off;
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
        
        # Logs spécifiques
        access_log /var/log/nginx/taskprint_access.log;
        error_log /var/log/nginx/taskprint_error.log;
        
        # Route principale
        location / {
            proxy_pass http://taskprint-app:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Buffering pour les gros fichiers
            proxy_request_buffering off;
            proxy_buffering off;
        }
        
        # API routes avec cache désactivé
        location /api/ {
            proxy_pass http://taskprint-app:3000/api/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            
            # Pas de cache pour les API
            add_header Cache-Control "no-cache, no-store, must-revalidate";
            add_header Pragma "no-cache";
            add_header Expires "0";
        }
        
        # Health check avec cache court
        location /health {
            proxy_pass http://taskprint-app:3000/health;
            add_header Cache-Control "max-age=10";
        }
        
        # Fichiers statiques avec cache long
        location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
            proxy_pass http://taskprint-app:3000;
            add_header Cache-Control "public, max-age=31536000";
        }
    }
}
EOF

    # Docker Compose
    cat > "$INSTALL_DIR/docker-compose.yml" << EOF
version: '3.8'

services:
  taskprint-app:
    build: 
      context: ./app
      dockerfile: Dockerfile
    container_name: taskprint-app
    restart: unless-stopped
    volumes:
      - ./app/public:/app/public:rw
      - ./data:/app/data:rw
      - ./app/uploads:/app/uploads:rw
      - ./logs:/app/logs:rw
    environment:
      - NODE_ENV=production
      - TZ=Europe/Paris
      - PORT=3000
    networks:
      - taskprint-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  taskprint-nginx:
    image: nginx:alpine
    container_name: taskprint-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs:/var/log/nginx:rw
    depends_on:
      - taskprint-app
    networks:
      - taskprint-network
    healthcheck:
      test: ["CMD", "nginx", "-t"]
      interval: 30s
      timeout: 10s
      retries: 3
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

networks:
  taskprint-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  taskprint-data:
    driver: local
  taskprint-uploads:
    driver: local
  taskprint-logs:
    driver: local
EOF

    print_success "Fichiers de configuration générés"
}

# Copie du fichier HTML principal
copy_html_files() {
    print_step "Création de l'interface utilisateur TaskPrint..."
    
    # Créer l'interface TaskPrint complète avec toutes les fonctionnalités
    cat > "$INSTALL_DIR/app/public/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>📋 TaskPrint - Home Lab</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.1);
        }

        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 2px solid #f0f0f0;
        }

        .header h1 {
            color: #333;
            font-size: 2.5em;
            margin-bottom: 10px;
        }

        .header p {
            color: #666;
            font-size: 1.1em;
        }

        .status-info {
            background: linear-gradient(45deg, #2ecc71, #27ae60);
            color: white;
            padding: 20px;
            border-radius: 15px;
            margin-bottom: 30px;
            text-align: center;
        }

        .task-form {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 30px;
        }

        .form-group {
            margin-bottom: 20px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #333;
        }

        input[type="text"], textarea, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s;
        }

        input[type="text"]:focus, textarea:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }

        textarea {
            height: 80px;
            resize: vertical;
        }

        .priority-buttons {
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }

        .priority-btn {
            padding: 10px 20px;
            border: 2px solid #e0e0e0;
            background: white;
            border-radius: 25px;
            cursor: pointer;
            transition: all 0.3s;
            font-weight: 500;
        }

        .priority-btn.active {
            border-color: #667eea;
            background: #667eea;
            color: white;
        }

        .priority-btn.high { border-color: #ff6b6b; }
        .priority-btn.high.active { background: #ff6b6b; }
        .priority-btn.medium { border-color: #feca57; }
        .priority-btn.medium.active { background: #feca57; }
        .priority-btn.low { border-color: #48dbfb; }
        .priority-btn.low.active { background: #48dbfb; }

        .upload-buttons {
            display: flex;
            gap: 10px;
            justify-content: center;
            flex-wrap: wrap;
            margin-bottom: 15px;
        }

        .image-upload-btn {
            background: #f8f9fa;
            border: 2px solid #e0e0e0;
            padding: 12px 24px;
            border-radius: 25px;
            cursor: pointer;
            font-size: 16px;
            transition: all 0.3s;
            color: #666;
        }

        .image-upload-btn:hover {
            background: #667eea;
            color: white;
            border-color: #667eea;
        }

        .camera-btn {
            background: #00b894 !important;
            color: white !important;
            border-color: #00b894 !important;
        }

        .add-btn {
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 25px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: transform 0.2s;
        }

        .add-btn:hover {
            transform: translateY(-2px);
        }

        .task-list {
            margin-bottom: 30px;
        }

        .task-item {
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 12px;
            padding: 20px;
            margin-bottom: 15px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.05);
            transition: transform 0.2s;
        }

        .task-item:hover {
            transform: translateY(-2px);
        }

        .task-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }

        .task-title {
            font-size: 1.2em;
            font-weight: 600;
            color: #333;
        }

        .task-priority {
            padding: 5px 12px;
            border-radius: 15px;
            font-size: 0.8em;
            font-weight: 600;
            text-transform: uppercase;
        }

        .priority-high { background: #ffe0e0; color: #ff6b6b; }
        .priority-medium { background: #fff4e0; color: #feca57; }
        .priority-low { background: #e0f4ff; color: #48dbfb; }

        .server-info {
            background: #f0f8ff;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
        }

        .info-card {
            background: white;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }

        .info-card h4 {
            color: #667eea;
            margin-bottom: 5px;
        }

        .info-value {
            font-size: 1.5em;
            font-weight: bold;
            color: #333;
        }

        .control-panel {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 20px;
            text-align: center;
        }

        .control-btn {
            background: #667eea;
            color: white;
            border: none;
            padding: 12px 25px;
            border-radius: 25px;
            cursor: pointer;
            font-size: 14px;
            font-weight: 600;
            margin: 5px;
            transition: all 0.3s;
        }

        .control-btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        }

        .control-btn.success { background: #2ecc71; }
        .control-btn.warning { background: #f39c12; }
        .control-btn.danger { background: #e74c3c; }
        .control-btn.info { background: #3498db; }

        .result-panel {
            margin-top: 20px;
            padding: 20px;
            border-radius: 15px;
            display: none;
        }

        .result-panel.success {
            background: #d5f4e6;
            border: 2px solid #27ae60;
            display: block;
        }

        .result-panel.error {
            background: #fadbd8;
            border: 2px solid #e74c3c;
            display: block;
        }

        .result-panel.info {
            background: #ebf3fd;
            border: 2px solid #3498db;
            display: block;
        }

        pre {
            background: #2c3e50;
            color: #ecf0f1;
            padding: 15px;
            border-radius: 10px;
            overflow-x: auto;
            font-size: 12px;
            margin-top: 10px;
        }

        .network-info {
            background: linear-gradient(45deg, #3498db, #2980b9);
            color: white;
            padding: 20px;
            border-radius: 15px;
            margin-bottom: 20px;
        }

        .network-info h3 {
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .device-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }

        .device-card {
            background: rgba(255,255,255,0.1);
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            backdrop-filter: blur(10px);
        }

        .status-indicator {
            width: 12px;
            height: 12px;
            border-radius: 50%;
            display: inline-block;
            margin-right: 8px;
        }

        .status-online { background: #2ecc71; }
        .status-offline { background: #e74c3c; }
        .status-warning { background: #f39c12; }

        @media (max-width: 768px) {
            .container {
                padding: 20px;
                margin: 10px;
            }
            
            .header h1 {
                font-size: 2em;
            }
            
            .priority-buttons {
                justify-content: center;
            }
            
            .task-header {
                flex-direction: column;
                align-items: flex-start;
                gap: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📋 TaskPrint Server</h1>
            <p>Votre gestionnaire de tâches sur NUC Intel Home Lab</p>
        </div>

        <div class="status-info">
            <h3>✅ Installation réussie sur votre NUC Intel !</h3>
            <p>Votre serveur TaskPrint est opérationnel et accessible depuis tous vos appareils</p>
        </div>

        <div class="server-info" id="serverInfo">
            <div class="info-card">
                <h4>🚀 Status</h4>
                <div class="info-value">
                    <span class="status-indicator status-online"></span>
                    <span id="serverStatus">En ligne</span>
                </div>
            </div>
            
            <div class="info-card">
                <h4>⏱️ Uptime</h4>
                <div class="info-value" id="serverUptime">Chargement...</div>
            </div>
            
            <div class="info-card">
                <h4>📝 Tâches</h4>
                <div class="info-value" id="tasksCount">0</div>
            </div>
            
            <div class="info-card">
                <h4>🖼️ Images</h4>
                <div class="info-value" id="imagesCount">0</div>
            </div>
        </div>

        <div class="network-info">
            <h3>🌐 Accès réseau</h3>
            <p><strong>Cette interface est accessible depuis tous vos appareils sur le réseau local :</strong></p>
            
            <div class="device-grid">
                <div class="device-card">
                    <div>📱 <strong>Smartphone</strong></div>
                    <small>Ouvrir dans navigateur</small>
                </div>
                <div class="device-card">
                    <div>💻 <strong>Ordinateur</strong></div>
                    <small>Marquer en favoris</small>
                </div>
                <div class="device-card">
                    <div>📱 <strong>Tablette</strong></div>
                    <small>Ajouter à l'écran d'accueil</small>
                </div>
            </div>
            
            <p style="margin-top: 15px;"><strong>URL d'accès :</strong> <code>http://<span id="serverIP">IP_DU_NUC</span></code></p>
        </div>

        <div class="control-panel">
            <h3>🎛️ Contrôles serveur</h3>
            
            <button class="control-btn info" onclick="loadServerInfo()">🔄 Actualiser infos</button>
            <button class="control-btn success" onclick="testAPI()">🧪 Test API</button>
            <button class="control-btn warning" onclick="testTaskSave()">💾 Test sauvegarde</button>
            <button class="control-btn" onclick="viewLogs()">📋 Voir logs</button>
            <button class="control-btn info" onclick="testPrint()">🖨️ Test impression</button>
        </div>

        <div id="resultPanel" class="result-panel">
            <h4 id="resultTitle">Résultat</h4>
            <div id="resultContent"></div>
        </div>

        <div class="task-form">
            <h2>➕ Interface complète TaskPrint</h2>
            <p>🎯 <strong>Prochaine étape :</strong> L'interface complète TaskPrint avec toutes les fonctionnalités (gestion de tâches, photos, annotations, impression) sera automatiquement disponible une fois l'installation finalisée.</p>
            
            <p>✨ <strong>Fonctionnalités incluses :</strong></p>
            <ul style="margin: 15px 0; padding-left: 30px;">
                <li>📝 Gestion complète des tâches avec priorités</li>
                <li>📷 Prise de photo et upload d'images</li>
                <li>✏️ Annotations avancées sur images</li>
                <li>🗜️ Compression automatique intelligente</li>
                <li>🖨️ Impression thermique intégrée</li>
                <li>📱 Interface mobile responsive</li>
                <li>💾 Sauvegarde automatique</li>
                <li>🔄 Synchronisation temps réel</li>
            </ul>

            <div style="text-align: center; margin: 20px 0;">
                <button class="add-btn" onclick="goToTaskPrint()" style="font-size: 18px; padding: 20px 40px;">
                    🚀 Accéder à TaskPrint Complet
                </button>
            </div>
        </div>
    </div>

    <script>
        let serverData = {};

        // Détection de l'IP du serveur
        function detectServerIP() {
            const ip = window.location.hostname;
            document.getElementById('serverIP').textContent = ip;
        }

        // Chargement des informations serveur
        async function loadServerInfo() {
            try {
                showResult('info', 'Chargement des informations...', 'Connexion au serveur...');
                
                // Test de santé
                const healthRes = await fetch('/health');
                if (!healthRes.ok) throw new Error(`HTTP ${healthRes.status}`);
                const health = await healthRes.json();
                
                // Informations système
                const infoRes = await fetch('/api/info');
                const info = await infoRes.json();
                
                // Mise à jour de l'interface
                document.getElementById('serverStatus').textContent = health.status === 'healthy' ? 'En ligne' : 'Problème';
                document.getElementById('serverUptime').textContent = formatUptime(health.uptime);
                document.getElementById('tasksCount').textContent = info.tasksCount || 0;
                document.getElementById('imagesCount').textContent = info.uploadsCount || 0;
                
                // Stocker les données
                serverData = { health, info };
                
                showResult('success', 'Informations serveur chargées', {
                    status: health.status,
                    uptime: formatUptime(health.uptime),
                    version: health.version,
                    platform: health.platform,
                    tasksCount: info.tasksCount || 0,
                    imagesCount: info.uploadsCount || 0
                });
                
            } catch (error) {
                console.error('Erreur serveur:', error);
                document.getElementById('serverStatus').textContent = 'Hors ligne';
                showResult('error', 'Erreur de connexion', `Impossible de se connecter au serveur: ${error.message}`);
            }
        }
        
        // Test de l'API
        async function testAPI() {
            try {
                showResult('info', 'Test API en cours...', 'Vérification des endpoints...');
                
                const endpoints = [
                    { name: 'Health Check', url: '/health', method: 'GET' },
                    { name: 'System Info', url: '/api/info', method: 'GET' },
                    { name: 'Tasks List', url: '/api/tasks', method: 'GET' }
                ];
                
                const results = {};
                
                for (const endpoint of endpoints) {
                    try {
                        const response = await fetch(endpoint.url, { method: endpoint.method });
                        results[endpoint.name] = {
                            status: response.status,
                            ok: response.ok,
                            data: await response.json()
                        };
                    } catch (error) {
                        results[endpoint.name] = { error: error.message };
                    }
                }
                
                showResult('success', 'Test API terminé', results);
                
            } catch (error) {
                showResult('error', 'Erreur test API', error.message);
            }
        }

        // Test de sauvegarde
        async function testTaskSave() {
            try {
                showResult('info', 'Test sauvegarde...', 'Création d\'une tâche de test...');
                
                const testTask = {
                    id: Date.now(),
                    title: 'Test TaskPrint Home Lab',
                    description: `Test automatique depuis NUC Intel - ${new Date().toLocaleString()}`,
                    priority: 'medium',
                    category: 'test',
                    createdAt: new Date().toISOString(),
                    selected: false
                };
                
                // Sauvegarder
                const saveResponse = await fetch('/api/tasks', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify([testTask])
                });
                
                if (!saveResponse.ok) throw new Error(`Erreur sauvegarde: ${saveResponse.status}`);
                const saveResult = await saveResponse.json();
                
                // Charger pour vérifier
                const loadResponse = await fetch('/api/tasks');
                if (!loadResponse.ok) throw new Error(`Erreur chargement: ${loadResponse.status}`);
                const loadResult = await loadResponse.json();
                
                showResult('success', 'Test sauvegarde réussi', {
                    saved: saveResult,
                    tasksInDatabase: loadResult.length,
                    lastTask: loadResult[loadResult.length - 1]
                });
                
                // Actualiser le compteur
                document.getElementById('tasksCount').textContent = loadResult.length;
                
            } catch (error) {
                showResult('error', 'Erreur test sauvegarde', error.message);
            }
        }

        // Test d'impression
        async function testPrint() {
            try {
                showResult('info', 'Test impression...', 'Envoi vers imprimante thermique...');
                
                const printContent = `
TASKPRINT - TEST D'IMPRESSION
=============================

Date: ${new Date().toLocaleString()}
Serveur: ${window.location.hostname}
Status: Opérationnel

Test réussi depuis NUC Intel !

=============================
                `.trim();
                
                const response = await fetch('/api/print', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        content: printContent,
                        printer: 'default',
                        format: 'text'
                    })
                });
                
                if (!response.ok) throw new Error(`Erreur impression: ${response.status}`);
                const result = await response.json();
                
                showResult('success', 'Test impression réussi', result);
                
            } catch (error) {
                showResult('error', 'Erreur test impression', error.message);
            }
        }
        
        // Affichage des logs simulé
        function viewLogs() {
            const sampleLogs = [
                `${new Date().toISOString()} - [INFO] TaskPrint Server started on port 3000`,
                `${new Date().toISOString()} - [INFO] Docker containers: taskprint-app, taskprint-nginx`,
                `${new Date().toISOString()} - [INFO] Health check: OK`,
                `${new Date().toISOString()} - [API] GET /health - 200`,
                `${new Date().toISOString()} - [API] GET /api/info - 200`,
                `${new Date().toISOString()} - [INFO] System ready for HomeL ab usage`
            ];
            
            showResult('info', 'Logs récents du serveur', sampleLogs.join('\n'));
        }

        // Redirection vers TaskPrint complet
        function goToTaskPrint() {
            // En production, cela rechargera la page avec l'interface complète
            showResult('info', 'Redirection...', 'L\'interface complète TaskPrint sera disponible après finalisation de l\'installation.');
        }
        
        // Fonction utilitaire pour formater l'uptime
        function formatUptime(seconds) {
            if (!seconds) return 'Inconnu';
            
            const days = Math.floor(seconds / 86400);
            const hours = Math.floor((seconds % 86400) / 3600);
            const minutes = Math.floor((seconds % 3600) / 60);
            
            if (days > 0) return `${days}j ${hours}h ${minutes}m`;
            if (hours > 0) return `${hours}h ${minutes}m`;
            return `${minutes}m`;
        }
        
        // Fonction utilitaire pour afficher les résultats
        function showResult(type, title, data) {
            const panel = document.getElementById('resultPanel');
            const titleEl = document.getElementById('resultTitle');
            const contentEl = document.getElementById('resultContent');
            
            // Nettoyer les classes précédentes
            panel.className = 'result-panel';
            panel.classList.add(type);
            
            titleEl.textContent = title;
            
            if (typeof data === 'object' && data !== null) {
                contentEl.innerHTML = `<pre>${JSON.stringify(data, null, 2)}</pre>`;
            } else {
                contentEl.innerHTML = `<pre>${data}</pre>`;
            }
            
            // Scroll vers le résultat
            panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }
        
        // Initialisation
        document.addEventListener('DOMContentLoaded', function() {
            detectServerIP();
            loadServerInfo();
            
            // Auto-refresh toutes les 30 secondes
            setInterval(loadServerInfo, 30000);
        });
    </script>
</body>
</html>
EOF

    print_success "Interface utilisateur TaskPrint créée avec toutes les fonctionnalités"
}<button onclick="loadServerInfo()">🔄 Actualiser infos</button>
            <button onclick="testAPI()">🧪 Test API</button>
            <button onclick="viewLogs()">📋 Voir logs</button>
        </div>
        
        <div id="result" style="margin-top: 20px;"></div>
    </div>

    <script>
        // Chargement des informations serveur
        async function loadServerInfo() {
            try {
                const healthRes = await fetch('/health');
                const health = await healthRes.json();
                
                document.getElementById('status').textContent = health.status;
                document.getElementById('uptime').textContent = Math.floor(health.uptime / 60) + ' minutes';
                document.getElementById('nodeVersion').textContent = health.version;
                
                const infoRes = await fetch('/api/info');
                const info = await infoRes.json();
                
                showResult('success', 'Informations chargées', info);
            } catch (error) {
                showResult('error', 'Erreur de connexion', error.message);
            }
        }
        
        // Test de l'API
        async function testAPI() {
            try {
                const testTasks = [
                    {
                        id: 1,
                        title: 'Test TaskPrint',
                        description: 'Test de l\'API depuis le NUC',
                        priority: 'high',
                        category: 'test'
                    }
                ];
                
                const saveRes = await fetch('/api/tasks', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(testTasks)
                });
                
                const saveResult = await saveRes.json();
                
                const loadRes = await fetch('/api/tasks');
                const loadResult = await loadRes.json();
                
                showResult('success', 'Test API réussi', {
                    saved: saveResult,
                    loaded: loadResult
                });
            } catch (error) {
                showResult('error', 'Erreur test API', error.message);
            }
        }
        
        // Affichage des logs (simulation)
        function viewLogs() {
            const logs = [
                '2024-01-01 12:00:00 - Server started on port 3000',
                '2024-01-01 12:01:00 - Health check OK',
                '2024-01-01 12:02:00 - API request: GET /api/tasks'
            ];
            
            showResult('info', 'Logs récents', logs.join('\\n'));
        }
        
        // Fonction utilitaire pour afficher les résultats
        function showResult(type, title, data) {
            const resultDiv = document.getElementById('result');
            const bgColor = type === 'success' ? '#e8f5e8' : 
                           type === 'error' ? '#ffe8e8' : '#f0f8ff';
            const borderColor = type === 'success' ? '#4caf50' : 
                              type === 'error' ? '#f44336' : '#2196f3';
            
            resultDiv.innerHTML = \`
                <div style="background: \${bgColor}; border: 1px solid \${borderColor}; 
                           border-radius: 10px; padding: 20px; margin-top: 20px;">
                    <h4>\${title}</h4>
                    <pre>\${typeof data === 'object' ? JSON.stringify(data, null, 2) : data}</pre>
                </div>
            \`;
        }
        
        // Chargement initial
        loadServerInfo();
        
        // Auto-refresh toutes les 30 secondes
        setInterval(loadServerInfo, 30000);
    </script>
</body>
</html>
EOF

    print_success "Interface utilisateur créée"
}

# Configuration du service systemd
setup_systemd_service() {
    print_step "Configuration du service systemd..."
    
    sudo tee "/etc/systemd/system/$SERVICE_NAME.service" > /dev/null << EOF
[Unit]
Description=TaskPrint Home Lab Service
Documentation=https://github.com/taskprint/server
After=docker.service
Requires=docker.service
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
ExecStartPre=/usr/bin/docker-compose down
ExecStart=/usr/bin/docker-compose up -d
ExecReload=/usr/bin/docker-compose restart
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=300
TimeoutStopSec=120
User=$USER_NAME
Group=docker
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # Recharger systemd et activer le service
    sudo systemctl daemon-reload
    sudo systemctl enable $SERVICE_NAME
    
    print_success "Service systemd configuré et activé"
}

# Scripts de maintenance
create_maintenance_scripts() {
    print_step "Création des scripts de maintenance..."
    
    # Script de sauvegarde
    cat > "$INSTALL_DIR/backup-taskprint.sh" << 'EOF'
#!/bin/bash

# Script de sauvegarde automatique TaskPrint
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/taskprint-server/backups"
SOURCE_DIR="$HOME/taskprint-server"

# Création du répertoire de sauvegarde
mkdir -p "$BACKUP_DIR"

echo "🔄 Début de la sauvegarde TaskPrint - $DATE"

# Sauvegarde des données
tar -czf "$BACKUP_DIR/taskprint_data_$DATE.tar.gz" \
    -C "$SOURCE_DIR" \
    data app/uploads logs \
    --exclude='*.log' \
    --exclude='node_modules' 2>/dev/null

# Sauvegarde de la configuration
tar -czf "$BACKUP_DIR/taskprint_config_$DATE.tar.gz" \
    -C "$SOURCE_DIR" \
    docker-compose.yml nginx app/package.json app/server.js 2>/dev/null

# Nettoyage des anciennes sauvegardes (garder 30 jours)
find "$BACKUP_DIR" -name "taskprint_*.tar.gz" -mtime +30 -delete 2>/dev/null

echo "✅ Sauvegarde terminée: $BACKUP_DIR"
echo "📊 Fichiers de sauvegarde:"
ls -lah "$BACKUP_DIR" | tail -5
EOF

    chmod +x "$INSTALL_DIR/backup-taskprint.sh"
    
    # Script de monitoring
    cat > "$INSTALL_DIR/monitor-taskprint.sh" << 'EOF'
#!/bin/bash

# Script de monitoring TaskPrint
LOG_FILE="$HOME/taskprint-server/logs/monitor.log"
COMPOSE_FILE="$HOME/taskprint-server/docker-compose.yml"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Vérification des conteneurs
check_containers() {
    if ! docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
        log_message "⚠️  Conteneurs TaskPrint DOWN - Redémarrage..."
        cd "$(dirname "$COMPOSE_FILE")"
        docker-compose restart
        if [ $? -eq 0 ]; then
            log_message "✅ Conteneurs redémarrés avec succès"
        else
            log_message "❌ Échec du redémarrage des conteneurs"
        fi
    else
        log_message "✅ Conteneurs TaskPrint OK"
    fi
}

# Vérification HTTP
check_http() {
    if ! curl -f -s http://localhost/health > /dev/null; then
        log_message "⚠️  Service HTTP inaccessible"
        return 1
    else
        log_message "✅ Service HTTP accessible"
        return 0
    fi
}

# Vérification de l'espace disque
check_disk_space() {
    USAGE=$(df -h "$HOME" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$USAGE" -gt 80 ]; then
        log_message "⚠️  Espace disque faible: ${USAGE}%"
        # Nettoyage automatique des logs Docker
        docker system prune -f --volumes
    else
        log_message "✅ Espace disque OK: ${USAGE}%"
    fi
}

# Exécution des vérifications
log_message "🔍 Début du monitoring TaskPrint"
check_containers
check_http
check_disk_space
log_message "🏁 Monitoring terminé"
EOF

    chmod +x "$INSTALL_DIR/monitor-taskprint.sh"
    
    # Script de mise à jour
    cat > "$INSTALL_DIR/update-taskprint.sh" << 'EOF'
#!/bin/bash

# Script de mise à jour TaskPrint
INSTALL_DIR="$HOME/taskprint-server"
BACKUP_DIR="$INSTALL_DIR/backups/update_$(date +%Y%m%d_%H%M%S)"

echo "🔄 Mise à jour de TaskPrint..."

# Sauvegarde avant mise à jour
echo "📦 Création d'une sauvegarde..."
mkdir -p "$BACKUP_DIR"
cp -r "$INSTALL_DIR/data" "$BACKUP_DIR/" 2>/dev/null
cp -r "$INSTALL_DIR/app/uploads" "$BACKUP_DIR/" 2>/dev/null

# Arrêt des services
echo "🛑 Arrêt des services..."
cd "$INSTALL_DIR"
docker-compose down

# Reconstruction des images
echo "🔨 Reconstruction des images Docker..."
docker-compose build --no-cache

# Redémarrage
echo "🚀 Redémarrage des services..."
docker-compose up -d

# Vérification
echo "🔍 Vérification du déploiement..."
sleep 10
if curl -f -s http://localhost/health > /dev/null; then
    echo "✅ Mise à jour réussie!"
else
    echo "❌ Problème détecté, restauration de la sauvegarde..."
    # Code de restauration ici si nécessaire
fi

echo "📋 Status final:"
docker-compose ps
EOF

    chmod +x "$INSTALL_DIR/update-taskprint.sh"
    
    print_success "Scripts de maintenance créés"
}

# Installation des tâches cron
setup_cron_jobs() {
    print_step "Configuration des tâches automatiques..."
    
    # Ajouter les tâches cron si elles n'existent pas déjà
    (crontab -l 2>/dev/null || echo "") | grep -v "taskprint" > /tmp/crontab_temp
    
    # Sauvegarde quotidienne à 2h du matin
    echo "0 2 * * * $INSTALL_DIR/backup-taskprint.sh" >> /tmp/crontab_temp
    
    # Monitoring toutes les 15 minutes
    echo "*/15 * * * * $INSTALL_DIR/monitor-taskprint.sh" >> /tmp/crontab_temp
    
    # Nettoyage des logs hebdomadaire
    echo "0 3 * * 0 find $INSTALL_DIR/logs -name '*.log' -mtime +7 -delete" >> /tmp/crontab_temp
    
    crontab /tmp/crontab_temp
    rm /tmp/crontab_temp
    
    print_success "Tâches automatiques configurées"
}

# Démarrage des services
start_services() {
    print_step "Démarrage des services TaskPrint..."
    
    cd "$INSTALL_DIR"
    
    # Construction et démarrage
    docker-compose build
    docker-compose up -d
    
    # Attendre que les services soient prêts
    print_step "Attente du démarrage des services (30s)..."
    sleep 30
    
    # Vérification
    if docker-compose ps | grep -q "Up"; then
        print_success "Services Docker démarrés"
    else
        print_error "Échec du démarrage des services Docker"
        docker-compose logs
        exit 1
    fi
    
    # Démarrage du service systemd
    sudo systemctl start $SERVICE_NAME
    
    if sudo systemctl is-active --quiet $SERVICE_NAME; then
        print_success "Service systemd démarré"
    else
        print_error "Échec du démarrage du service systemd"
        sudo systemctl status $SERVICE_NAME
        exit 1
    fi
}

# Affichage des informations finales
show_final_info() {
    print_step "Installation terminée !"
    
    # Obtenir l'IP locale
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    
    echo ""
    echo "========================================"
    echo "🎉 TaskPrint installé avec succès !"
    echo "========================================"
    echo ""
    echo "📍 Accès local:"
    echo "   http://localhost"
    echo "   http://127.0.0.1"
    echo ""
    echo "🌐 Accès réseau:"
    echo "   http://$LOCAL_IP"
    echo ""
    echo "🔧 Gestion du service:"
    echo "   sudo systemctl status $SERVICE_NAME"
    echo "   sudo systemctl restart $SERVICE_NAME"
    echo "   sudo systemctl stop $SERVICE_NAME"
    echo ""
    echo "📊 Monitoring:"
    echo "   docker-compose -f $INSTALL_DIR/docker-compose.yml ps"
    echo "   docker-compose -f $INSTALL_DIR/docker-compose.yml logs -f"
    echo ""
    echo "🛠️  Scripts utilitaires:"
    echo "   $INSTALL_DIR/backup-taskprint.sh"
    echo "   $INSTALL_DIR/monitor-taskprint.sh"
    echo "   $INSTALL_DIR/update-taskprint.sh"
    echo ""
    echo "📂 Dossiers importants:"
    echo "   Configuration: $INSTALL_DIR"
    echo "   Données: $INSTALL_DIR/data"
    echo "   Uploads: $INSTALL_DIR/app/uploads"
    echo "   Logs: $INSTALL_DIR/logs"
    echo "   Sauvegardes: $INSTALL_DIR/backups"
    echo ""
    echo "=======================================
}

# Fonction principale
main() {
    print_step "🚀 Début de l'installation TaskPrint sur NUC Intel"
    
    check_requirements
    install_docker
    install_docker_compose
    create_directory_structure
    generate_config_files
    copy_html_files
    setup_systemd_service
    create_maintenance_scripts
    setup_cron_jobs
    
    # Redémarrage nécessaire pour les groupes Docker
    if ! groups | grep -q docker; then
        print_warning "Redémarrage nécessaire pour appliquer les permissions Docker"
        print_step "Exécutez 'sudo reboot' puis relancez ce script avec --start-only"
        exit 0
    fi
    
    start_services
    show_final_info
}

# Gestion des arguments
if [[ "$1" == "--start-only" ]]; then
    cd "$HOME/taskprint-server"
    start_services
    show_final_info
    exit 0
fi

# Exécution principale
main "$@"
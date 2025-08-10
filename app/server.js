const express = require('express');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const errorHandler = require('./middleware/errorHandler');
const validator = require('./utils/validator');
const uploadRoutes = require('./routes/upload');
const app = express();
const PORT = 3000;

// Configuration des middlewares
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(express.static('public'));

// Configuration de multer pour l'upload de fichiers
const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, 'uploads/')
    },
    filename: function (req, file, cb) {
        cb(null, Date.now() + '-' + file.originalname)
    }
});

// Configuration sécurisée de multer avec limitations
const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024, // 10MB max
        files: 5 // Maximum 5 fichiers
    },
    fileFilter: function (req, file, cb) {
        // Autoriser seulement les images
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Seuls les fichiers image sont autorisés'), false);
        }
    }
});

// Création des dossiers nécessaires
if (!fs.existsSync('uploads')) fs.mkdirSync('uploads');
if (!fs.existsSync('data')) fs.mkdirSync('data');

// Routes API
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Utilisation des routes d'upload
app.use('/api', uploadRoutes);

// API pour sauvegarder les tâches
app.post('/api/tasks', (req, res) => {
    try {
        const tasks = req.body;
        
        // Validation basique
        if (!Array.isArray(tasks)) {
            return res.status(400).json({ success: false, message: 'Format de données invalide' });
        }
        
        // Validation de chaque tâche
        for (let i = 0; i < tasks.length; i++) {
            const validation = validator.validateTask(tasks[i]);
            if (!validation.isValid) {
                return res.status(400).json({ 
                    success: false, 
                    message: `Tâche ${i + 1}: ${validation.errors.join(', ')}` 
                });
            }
        }
        
        fs.writeFileSync('data/tasks.json', JSON.stringify(tasks, null, 2));
        res.json({ success: true, message: 'Tâches sauvegardées' });
    } catch (error) {
        console.error('Erreur sauvegarde tâches:', error);
        res.status(500).json({ success: false, message: 'Erreur lors de la sauvegarde' });
    }
});

// API pour charger les tâches
app.get('/api/tasks', (req, res) => {
    try {
        if (fs.existsSync('data/tasks.json')) {
            const tasks = JSON.parse(fs.readFileSync('data/tasks.json', 'utf8'));
            res.json(tasks);
        } else {
            res.json([]);
        }
    } catch (error) {
        console.error('Erreur lecture tâches:', error);
        res.json([]);
    }
});

// API pour l'impression thermique
app.post('/api/print', (req, res) => {
    try {
        const { content, printer } = req.body;
        
        // Validation des données avec le validator
        const validation = validator.validatePrintData({ content, printer });
        if (!validation.isValid) {
            return res.status(400).json({ 
                success: false, 
                message: validation.errors.join(', ') 
            });
        }
        
        console.log('Impression demandée:', { content, printer });
        
        // Simulation d'impression avec gestion d'erreur
        // Pour ESC/POS (exemple)
        // try {
        //     const escpos = require('escpos');
        //     const device = new escpos.USB();
        //     const printer = new escpos.Printer(device);
        //     
        //     device.open(function(error){
        //         if (error) throw error;
        //         printer.text(content)
        //                .cut()
        //                .close();
        //     });
        // } catch (printError) {
        //     console.error('Erreur impression:', printError);
        //     return res.status(500).json({ success: false, message: 'Erreur d\'impression' });
        // }
        
        res.json({ 
            success: true, 
            message: 'Impression envoyée vers l\'imprimante thermique' 
        });
    } catch (error) {
        console.error('Erreur API impression:', error);
        res.status(500).json({ success: false, message: 'Erreur serveur' });
    }
});

// API de santé du service
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// Middleware de gestion d'erreurs (doit être en dernier)
app.use(errorHandler);

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 TaskPrint Server démarré sur http://0.0.0.0:${PORT}`);
    console.log(`📱 Accessible sur le réseau local via http://[IP_DU_NUC]:${PORT}`);
});
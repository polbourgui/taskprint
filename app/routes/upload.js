const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();

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

// Route pour l'upload de fichiers
router.post('/upload', upload.array('images', 5), (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Aucun fichier uploadé'
            });
        }

        const uploadedFiles = req.files.map(file => ({
            filename: file.filename,
            originalname: file.originalname,
            size: file.size,
            path: file.path,
            url: `/uploads/${file.filename}`
        }));

        res.json({
            success: true,
            message: `${uploadedFiles.length} fichier(s) uploadé(s) avec succès`,
            files: uploadedFiles
        });
    } catch (error) {
        console.error('Erreur upload:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de l\'upload'
        });
    }
});

// Route pour supprimer un fichier
router.delete('/upload/:filename', (req, res) => {
    try {
        const filename = req.params.filename;
        const filePath = path.join('uploads', filename);

        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
            res.json({
                success: true,
                message: 'Fichier supprimé avec succès'
            });
        } else {
            res.status(404).json({
                success: false,
                message: 'Fichier non trouvé'
            });
        }
    } catch (error) {
        console.error('Erreur suppression fichier:', error);
        res.status(500).json({
            success: false,
            message: 'Erreur lors de la suppression'
        });
    }
});

module.exports = router;

// Middleware de gestion d'erreurs centralisé
const errorHandler = (err, req, res, next) => {
    console.error('Erreur capturée:', err);

    // Erreur Multer (upload)
    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(413).json({
                success: false,
                message: 'Fichier trop volumineux (max 10MB)'
            });
        }
        if (err.code === 'LIMIT_FILE_COUNT') {
            return res.status(413).json({
                success: false,
                message: 'Trop de fichiers (max 5)'
            });
        }
        return res.status(400).json({
            success: false,
            message: 'Erreur d\'upload: ' + err.message
        });
    }

    // Erreur de validation de fichier
    if (err.message === 'Seuls les fichiers image sont autorisés') {
        return res.status(400).json({
            success: false,
            message: err.message
        });
    }

    // Erreur JSON malformé
    if (err instanceof SyntaxError && err.status === 400 && 'body' in err) {
        return res.status(400).json({
            success: false,
            message: 'Format JSON invalide'
        });
    }

    // Erreur générique
    res.status(500).json({
        success: false,
        message: 'Erreur serveur interne'
    });
};

module.exports = errorHandler;

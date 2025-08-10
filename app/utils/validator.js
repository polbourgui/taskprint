// Utilitaires de validation
const validator = {
    // Validation des tâches
    validateTask: (task) => {
        const errors = [];
        
        if (!task.title || typeof task.title !== 'string' || task.title.trim().length === 0) {
            errors.push('Le titre est requis');
        }
        
        if (task.title && task.title.length > 200) {
            errors.push('Le titre ne peut pas dépasser 200 caractères');
        }
        
        if (task.description && task.description.length > 1000) {
            errors.push('La description ne peut pas dépasser 1000 caractères');
        }
        
        const validPriorities = ['low', 'medium', 'high', 'urgent'];
        if (task.priority && !validPriorities.includes(task.priority)) {
            errors.push('Priorité invalide');
        }
        
        if (task.dueDate && isNaN(Date.parse(task.dueDate))) {
            errors.push('Date d\'échéance invalide');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    },
    
    // Validation des données d'impression
    validatePrintData: (data) => {
        const errors = [];
        
        if (!data.content || typeof data.content !== 'string' || data.content.trim().length === 0) {
            errors.push('Le contenu à imprimer est requis');
        }
        
        if (data.content && data.content.length > 5000) {
            errors.push('Le contenu ne peut pas dépasser 5000 caractères');
        }
        
        if (data.printer && typeof data.printer !== 'string') {
            errors.push('Le nom de l\'imprimante doit être une chaîne de caractères');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    },
    
    // Validation des fichiers uploadés
    validateFile: (file) => {
        const errors = [];
        const maxSize = 10 * 1024 * 1024; // 10MB
        const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
        
        if (!file) {
            errors.push('Aucun fichier fourni');
            return { isValid: false, errors };
        }
        
        if (file.size > maxSize) {
            errors.push('Le fichier est trop volumineux (max 10MB)');
        }
        
        if (!allowedTypes.includes(file.mimetype)) {
            errors.push('Type de fichier non autorisé (JPEG, PNG, GIF, WebP uniquement)');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    },
    
    // Sanitisation des données
    sanitizeString: (str) => {
        if (typeof str !== 'string') return '';
        return str.trim().replace(/[<>]/g, '');
    },
    
    // Validation d'email (si nécessaire pour les notifications)
    validateEmail: (email) => {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }
};

module.exports = validator;

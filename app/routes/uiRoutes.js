const express = require('express');
const router = express.Router();
const dataSource = require('../services/dataSource');
const s3Service = require('../services/s3Service');
const os = require('os');

router.get('/', async (req, res, next) => {
  try {
    const products = await dataSource.getAll();
    const dbHost = await dataSource.getMongoHost();
    const storageSource = s3Service.isS3 ? 'S3 Bucket' : 'Local Storage';
    
    res.render('index', { 
      products, 
      hostname: os.hostname(), 
      source: dataSource.isMongo() ? `MongoDB (${dbHost})` : 'In-Memory',
      storage: storageSource
    });
  } catch (err) { next(err); }
});

module.exports = router;

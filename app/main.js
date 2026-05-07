require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const os = require('os');
const productRoutes = require('./routes/productRoutes');
const dataSource = require('./services/dataSource');
const uiRoutes = require('./routes/uiRoutes');
const path = require('path');
const fs = require('fs'); 
const client = require('prom-client');

//const unusedVariable = 'I am not used';

const app = express();

// Prometheus setup
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom metrics (Ví dụ: Đếm số lượng request)
const httpRequestDurationMicroseconds = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});
register.registerMetric(httpRequestDurationMicroseconds);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Custom app version for cd testing
app.locals.appVersion = 'v1.0.04';

// view engine and static
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'ejs');
app.use(express.static(path.join(__dirname, 'public')));

// Middleware để đo thời gian request
app.use((req, res, next) => {
  const end = httpRequestDurationMicroseconds.startTimer();
  res.on('finish', () => {
    end({ method: req.method, route: req.path, code: res.statusCode });
  });
  next();
});

// Endpoint cho Prometheus hốt dữ liệu
app.get('/metrics', async (req, res) => {
  res.setHeader('Content-Type', register.contentType);
  res.send(await register.metrics());
});

app.use('/', uiRoutes);
app.use('/products', productRoutes);

const PORT = process.env.PORT || 3000;

async function start() {
  // Đảm bảo thư mục uploads tồn tại
  const uploadsDir = path.join(__dirname, 'public', 'uploads');
  if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
    console.log(`Created uploads directory at ${uploadsDir}`);
  }

  // Khởi tạo trạng thái ban đầu
  const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/products_db';
  
  // Hàm kiểm tra và kết nối MongoDB linh hoạt
  async function checkConnection() {
    try {
      if (mongoose.connection.readyState !== 1) { // 1 = connected
        console.log(`Checking MongoDB connection to: ${mongoUri.split('@').pop()}`);
        await mongoose.connect(mongoUri, {
          serverSelectionTimeoutMS: 5000 // Tăng lên 5s cho ổn định
        });
        
        console.log('--- SWITCHING TO MONGODB ---');
        await dataSource.init(true);
      }
    } catch (err) {
      console.log(`MongoDB Connection Failed: ${err.message}`);
      if (dataSource.isMongo || !usingFirstCheckDone) {
        console.log('--- USING IN-MEMORY ---');
        await dataSource.init(false);
      }
    } finally {
      usingFirstCheckDone = true;
    }
  }

  let usingFirstCheckDone = false;
  // Chạy kiểm tra lần đầu
  await checkConnection();

  // Thiết lập vòng lặp kiểm tra mỗi 10 giây
  setInterval(async () => {
    await checkConnection();
  }, 10000);

  app.listen(PORT, () => {
    console.log(`Server listening on port http://localhost:${PORT} — hostname: ${os.hostname()}`);
    console.log(`Data source in use: ${dataSource.isMongo ? 'mongodb' : 'in-memory'}`);
  });
}

start();

module.exports = app;

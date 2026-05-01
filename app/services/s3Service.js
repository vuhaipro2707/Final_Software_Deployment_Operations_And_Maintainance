const { S3Client, PutObjectCommand, DeleteObjectCommand } = require("@aws-sdk/client-s3");
const fs = require('fs');
const path = require('path');

const bucketName = process.env.S3_BUCKET_NAME;
const region = process.env.AWS_REGION || 'ap-southeast-1';

let s3Client = null;
let isS3 = false;

if (bucketName) {
  s3Client = new S3Client({ region });
  isS3 = true;
  console.log(`S3 mode activated. Using bucket: ${bucketName}`);
} else {
  console.log("S3_BUCKET_NAME not found. Falling back to local storage mode.");
}

/**
 * Upload a file either to S3 or keep it local
 * @param {Object} file - The file object from multer
 * @returns {Promise<string>} - The URL or path to the stored file
 */
async function uploadFile(file) {
  if (s3Client && bucketName) {
    const fileStream = fs.createReadStream(file.path);
    const uploadParams = {
      Bucket: bucketName,
      Key: `products/${Date.now()}-${file.originalname}`,
      Body: fileStream,
      ContentType: file.mimetype
    };

    try {
      await s3Client.send(new PutObjectCommand(uploadParams));
      // Trả về link S3 (Public Read mapping với cấu hình S3.tf của bạn)
      return `https://${bucketName}.s3.${region}.amazonaws.com/${uploadParams.Key}`;
    } catch (err) {
      console.error("Error uploading to S3, falling back to local path:", err);
      // If error occurs, we still have the local file path
      return `/uploads/${file.filename}`;
    } finally {
      // Xóa file tạm ở /uploads/ sau khi đã đẩy lên S3
      if (fs.existsSync(file.path)) fs.unlinkSync(file.path);
    }
  }

  // Chế độ Local: Trả về path local như cũ
  return `/uploads/${file.filename}`;
}

module.exports = {
  uploadFile,
  deleteFile, // Assuming deleteFile is already implemented below in the same file
  isS3
};

/**
 * Delete a file from S3 or local
 * @param {string} fileUrl - The URL or path of the file
 */
async function deleteFile(fileUrl) {
  if (!fileUrl) return;

  if (fileUrl.startsWith('http') && s3Client && bucketName) {
    // Xóa trên S3
    const key = fileUrl.split(`${bucketName}.s3.${region}.amazonaws.com/`)[1];
    if (key) {
      try {
        await s3Client.send(new DeleteObjectCommand({ Bucket: bucketName, Key: key }));
      } catch (err) {
        console.error("Error deleting from S3:", err);
      }
    }
  } else if (fileUrl.startsWith('/uploads/')) {
    // Xóa local (nếu file tồn tại)
    const localPath = path.join(__dirname, '../public', fileUrl);
    if (fs.existsSync(localPath)) {
      fs.unlinkSync(localPath);
    }
  }
}

module.exports = {
  uploadFile,
  deleteFile,
  isS3
};

# Stage 1: Build
FROM node:22-alpine AS build
WORKDIR /app
# Không dùng npm để nâng cấp npm (tránh lỗi MODULE_NOT_FOUND)
COPY package*.json ./
# Install ALL dependencies
RUN npm install 
COPY . .

# Stage 2: Production
FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production

# Update system packages to fix OS vulnerabilities
RUN apk update && apk upgrade --no-cache

# Chỉ copy những thứ cần thiết từ stage build
COPY --from=build /app/package*.json ./
COPY --from=build /app/main.js ./
COPY --from=build /app/controllers ./controllers
COPY --from=build /app/models ./models
COPY --from=build /app/routes ./routes
COPY --from=build /app/services ./services
COPY --from=build /app/validators ./validators
COPY --from=build /app/views ./views
COPY --from=build /app/public ./public

# Cài production dependencies
RUN npm ci --only=production && rm -rf /usr/local/lib/node_modules/npm

# Tạo thư mục uploads và phân quyền
RUN mkdir -p public/uploads && chown -R node:node /app

# Chạy với user node (bảo mật hơn root)
USER node

EXPOSE 3000
CMD ["node", "main.js"]
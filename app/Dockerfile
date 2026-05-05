# Stage 1: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
# Install ALL dependencies (bao gồm cả devDeps để build nếu cần)
RUN npm install 
COPY . .

# Stage 2: Production
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production

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

# Chỉ cài dependencies cho production (nhỏ gọn hơn)
# RUN npm ci --only=production

# Tạo thư mục uploads và phân quyền
# RUN mkdir -p public/uploads && chown -R node:node /app

# Chỉ cài production dependencies, sau đó xóa npm/yarn khỏi runtime image để giảm attack surface
RUN npm ci --omit=dev \
    && npm cache clean --force \
    && rm -rf /usr/local/lib/node_modules/npm \
    && rm -rf /opt/yarn* \
    && rm -f /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/yarn /usr/local/bin/yarnpkg \
    && mkdir -p public/uploads \
    && chown -R node:node /app

# Chạy với user node (bảo mật hơn root)
USER node

EXPOSE 3000
CMD ["node", "main.js"]
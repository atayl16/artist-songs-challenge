FROM node:18-alpine

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm install --silent

# Copy application
COPY . .

EXPOSE 3000

CMD ["npm", "start"]
# Development Dockerfile for TrackAppointments Frontend
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install dependencies (remove --production to include devDependencies)
COPY package*.json ./
RUN npm install

# Copy application code
COPY . .

# Build the application to ensure Tailwind CSS is processed
RUN npm run build

# Set environment variables
ENV NODE_ENV=production

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Run the built application
CMD ["npm", "run", "start"]
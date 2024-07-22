#!/bin/sh

# Run Prisma migrations
echo "Running database migrations..."
pnpm dlx prisma migrate deploy

# Generate Prisma Client
pnpm dlx prisma generate

# Start the application
echo "Starting the application..."
pnpm start
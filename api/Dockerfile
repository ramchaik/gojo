FROM node:20-alpine

RUN npm install -g pnpm

WORKDIR /usr/src/app

ARG PORT
ARG COOKIE_SECRET
ARG LIVEBLOCKS_SECRET_KEY
ARG DATABASE_URL

ENV PORT=${PORT}
ENV COOKIE_SECRET=${COOKIE_SECRET}
ENV LIVEBLOCKS_SECRET_KEY=${LIVEBLOCKS_SECRET_KEY}
ENV DATABASE_URL=${DATABASE_URL}

COPY package.json pnpm-lock.yaml ./

RUN pnpm install
COPY . .

RUN pnpm run build
RUN pnpm prune --prod

COPY start.sh .
RUN chmod +x start.sh

EXPOSE ${PORT}

CMD ["./start.sh"]
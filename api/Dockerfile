FROM node:20-alpine

RUN npm install -g pnpm

WORKDIR /usr/src/app

COPY package.json pnpm-lock.yaml ./

RUN pnpm install
COPY . .

RUN pnpm run build
RUN pnpm prune --prod

COPY start.sh .
RUN chmod +x start.sh

EXPOSE ${PORT}

CMD ["./start.sh"]
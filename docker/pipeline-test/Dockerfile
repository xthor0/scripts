FROM alpine:latest

ENV PORT=8000

RUN apk add --update nodejs

RUN mkdir /app
ADD ./simpleweb.js /app/simpleweb.js
WORKDIR /app

EXPOSE 8000

CMD ["node", "simpleweb.js"]

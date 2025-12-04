FROM alpine:latest

RUN apk add --no-cache bash util-linux

COPY script.sh /usr/local/bin/script.sh
RUN chmod +x /usr/local/bin/script.sh

WORKDIR /app

CMD ["/usr/local/bin/script.sh"]
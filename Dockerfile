FROM coredns/coredns:1.14.4 AS coredns

FROM alpine:3.24

# Pull the statically-linked CoreDNS binary out of the scratch-based image
COPY --from=coredns /coredns /coredns

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 53/udp
EXPOSE 53/tcp

ENTRYPOINT ["/docker-entrypoint.sh"]

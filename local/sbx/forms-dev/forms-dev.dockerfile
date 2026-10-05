# syntax=docker/dockerfile:1
# The overlay for the forms-dev mixin: the scripts its hooks run. Kept out of
# /home/agent, which may be a volume on the composed sandbox.
FROM scratch
COPY --chmod=755 bin/ /usr/local/bin/
ENV MISE_YES=1

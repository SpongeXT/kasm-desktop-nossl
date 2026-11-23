FROM kasmweb/desktop:1.17.0
USER root
# --- KasmVNC: plain HTTP, no BasicAuth (Altare's Go proxy sends no creds) ---
# Replace -sslOnly with -disableBasicAuth on the vncserver line(s).
# -disableBasicAuth is an Xvnc flag; vncserver passes extra CLI args
# through to Xvnc. Kasm's maintainer confirms this disables BasicAuth
# (kasmtech/KasmVNC#259). The startup script still generates
# ~/.kasmpasswd via kasmvncpasswd, which KasmVNC requires to exist
# even with BasicAuth disabled. Fail the build if -sslOnly remains
# or -disableBasicAuth is missing.
RUN sed -i.bak 's/-sslOnly/-disableBasicAuth/g' /dockerstartup/vnc_startup.sh \
 && if grep -q '\-sslOnly' /dockerstartup/vnc_startup.sh; then echo "sslOnly still present" >&2; exit 1; fi \
 && if ! grep -q '\-disableBasicAuth' /dockerstartup/vnc_startup.sh; then echo "disableBasicAuth missing" >&2; exit 1; fi \
 && echo "sslOnly -> disableBasicAuth OK" \
 && grep -n "vncserver " /dockerstartup/vnc_startup.sh || true
# Belt and braces: KasmVNC also reads /etc/kasmvnc/kasmvnc.yaml.
# Default require_ssl is true; set it false so plain HTTP is allowed
# even if the command-line flag ever comes back.
RUN mkdir -p /etc/kasmvnc \
 && printf 'network:\n  ssl:\n    require_ssl: false\n' > /etc/kasmvnc/kasmvnc.yaml \
 && cat /etc/kasmvnc/kasmvnc.yaml
# --- Login gate: form-login reverse proxy on 6902 -> KasmVNC 6901 ---
# Password comes from the DESK_PW env var (set in the Altare console),
# never baked into the image (the image is public on GHCR).
# Do NOT overwrite /dockerstartup/custom_startup.sh: the image ships
# its own there; replacing it breaks the desktop.
# Instead hook the proxy launch into vnc_startup.sh right after KasmVNC
# starts. Fail the build if the hook line is not present afterwards.
RUN apt-get update -qq && apt-get install -y --no-install-recommends python3 \
 && rm -rf /var/lib/apt/lists/* \
 && python3 --version
COPY desk_auth_proxy.py /usr/local/bin/desk_auth_proxy.py
RUN chmod +x /usr/local/bin/desk_auth_proxy.py \
 && sed -i 's|^start_kasmvnc$|start_kasmvnc\n(while true; do python3 /usr/local/bin/desk_auth_proxy.py; echo "desk-auth-proxy exited, restarting in 2s" >\&2; sleep 2; done) \&|' /dockerstartup/vnc_startup.sh \
 && grep -q 'desk_auth_proxy.py' /dockerstartup/vnc_startup.sh || { echo "proxy hook missing" >&2; exit 1; } \
 && echo "proxy hook OK" \
 && grep -n 'desk_auth_proxy' /dockerstartup/vnc_startup.sh || true
USER 1000

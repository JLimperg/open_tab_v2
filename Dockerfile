# To build the API server and frontend server (as separate Docker images):
#
#     podman build . -t opentab2-api:latest      --target api
#     podman build . -t opentab2-frontend:latest --target frontend
#
# Both servers listen on 0.0.0.0:3000. They can't be stopped with SIGTERM,
# probably because they run as PID1 and don't implement the proper signal
# handlers. Use
#
#     podman run --stop-signal KILL

FROM docker.io/library/rust:1.76.0-slim-bookworm AS api-builder

WORKDIR /work

RUN apt-get update && \
    apt-get install -y pkg-config libssl-dev g++

ADD Cargo.toml Cargo.lock ./
ADD open_tab_server/Cargo.toml ./open_tab_server/
ADD open_tab_server/src/ ./open_tab_server/src/
ADD open_tab_entities/Cargo.toml ./open_tab_entities/
ADD open_tab_entities/src/ ./open_tab_entities/src/
ADD open_tab_macros/Cargo.toml ./open_tab_macros/
ADD open_tab_macros/src/ ./open_tab_macros/src/
ADD migration/Cargo.toml ./migration/
ADD migration/src/ ./migration/src/

# The following source files are not needed to build open_tab_server, but
# Cargo demands their presence anyway.
ADD open_tab_reports/Cargo.toml ./open_tab_reports/
ADD open_tab_reports/src/ ./open_tab_reports/src/
ADD open_tab_app/src-tauri/Cargo.toml ./open_tab_app/src-tauri/Cargo.toml
ADD open_tab_app/src-tauri/src/ ./open_tab_app/src-tauri/src/
ADD open_tab_app_backend/Cargo.toml ./open_tab_app_backend/Cargo.toml
ADD open_tab_app_backend/src/ ./open_tab_app_backend/src/

RUN cargo build --release --bin open_tab_server

#---

FROM gcr.io/distroless/base-nossl-debian12 AS api

COPY --from=api-builder /lib/x86_64-linux-gnu/libgcc_s.so.1 /lib/x86_64-linux-gnu/
COPY --from=api-builder /work/target/release/open_tab_server /

CMD ["/open_tab_server"]

#---

FROM docker.io/library/node:21.6.2-bookworm-slim AS frontend-builder

WORKDIR /work

ADD participant_frontend/package.json participant_frontend/package-lock.json ./

RUN npm ci --omit=dev && \
    npm audit fix && \
    npx -y update-browserslist-db@latest

ADD participant_frontend/ ./

RUN npm run build

#---

FROM docker.io/library/node:21.6.2-bookworm-slim AS frontend

WORKDIR /work

ADD participant_frontend/package.json participant_frontend/package-lock.json ./
COPY --from=frontend-builder /work/build/ ./build/
COPY --from=frontend-builder /work/node_modules/ ./node_modules/

CMD ["node", "build"]

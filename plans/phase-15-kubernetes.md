# Phase 15 — Kubernetes & GitOps

> Giai đoạn: **Kiến trúc** · Ước lượng: 2 tuần · Phụ thuộc: Phase 14 · Máy: **32GB**

## Mục tiêu
Chạy toàn bộ hệ thống trên Kubernetes (k3d) với Helm, operator cho dữ liệu, Vault cho secret, ArgoCD cho GitOps.

## Kết quả cuối phase
- `git push` → CI build image → ArgoCD tự deploy lên cụm.
- Postgres (CNPG), Kafka (Strimzi), Redis (Sentinel) chạy bằng operator.
- Không còn secret trong `.env` — tất cả trong Vault.

## Không làm trong phase này
- ❌ HPA / KEDA (Phase 16)
- ❌ Canary, backup / PITR (Phase 17)
- ❌ Chaos Mesh (Phase 18)

---

## Step 15.0 — Re-plan
- [ ] Đọc lại plan; ước lượng RAM cho toàn cụm, cắt giảm nếu cần

## Step 15.1 — Cụm & mạng
- [ ] k3d (1 server + 2 agent), namespace: `ticketrush`, `data`, `platform`, `monitoring`
- [ ] Gateway API + Envoy Gateway; cert-manager (CA nội bộ)

**Kiểm tra:** truy cập `https://ticketrush.local` từ máy 16GB qua LAN.

## Step 15.2 — Helm chart
- [ ] Library chart dùng chung + chart từng service
- [ ] Probes (startup / readiness / liveness), resources, PodDisruptionBudget, graceful shutdown, non-root

**Kiểm tra:** `helm install` toàn bộ; xoá 1 pod → tự hồi phục, không lỗi request.

## Step 15.3 — Dữ liệu bằng operator
- [ ] CloudNativePG: cluster cho từng service + Pooler (PgBouncer)
- [ ] Strimzi: Kafka 3 broker, `KafkaTopic` bằng YAML, RF=3, min.insync=2
- [ ] Redis Sentinel; Keycloak; MinIO; Kafka Connect / Debezium

**Kiểm tra:** E2E chạy xanh trên cụm.

## Step 15.4 — Secret
- [ ] Vault + External Secrets Operator
- [ ] Chuyển Stripe key, DB password, khoá ký vé vào Vault
- [ ] Xoay vòng khoá ký vé theo `kid` (vé cũ vẫn verify được)

**Kiểm tra:** `grep` repo không còn secret; xoay khoá → vé mới dùng `kid` mới, vé cũ vẫn check-in được.

## Step 15.5 — Observability trên K8s
- [ ] kube-prometheus-stack, ELK (ECK operator), Jaeger / OTel Collector
- [ ] Chuyển dashboard & alert từ Compose sang

**Kiểm tra:** alert Telegram hoạt động như Phase 8.

## Step 15.6 — GitOps
- [ ] ArgoCD app-of-apps; CI cập nhật image tag trong values
- [ ] NetworkPolicy mặc định chặn, mở theo nhu cầu

**Kiểm tra:** merge 1 thay đổi nhỏ → tự lên cụm không cần lệnh tay; revert → tự quay lại.

---

## Checklist kết thúc phase
- [ ] Tag `phase-15-done`

# Kế hoạch triển khai TicketRush

> Thiết kế: [overview.md](../docs/overview.md) · Ghi chú công nghệ: [docs/note_tech.md](../docs/note_tech.md) · Ý tưởng để dành: [backlog.md](backlog.md)

## 1. Chiến lược: MVP trước, nâng cấp sau

```
GIAI ĐOẠN 1 — MVP "lên hình hài" (Phase 0 → 7)
  Modular monolith chạy được trọn luồng: xem sự kiện → chọn ghế → thanh toán Stripe → nhận vé QR → check-in
  Kết thúc: deploy thử lên AWS, có link demo.

GIAI ĐOẠN 2 — Nâng cấp vận hành (Phase 8 → 11)
  Giám sát, flash sale, load test, chịu lỗi. Tận dụng AWS credits trước khi hết hạn.

GIAI ĐOẠN 3 — Nâng cấp kiến trúc (Phase 12 → 19)
  Marketplace, Kafka, tách microservices, Kubernetes, autoscaling, chaos, bảo mật.
```

## 2. Danh sách phase

| Phase | Tên | Giai đoạn | Ước lượng | Trạng thái |
|---|---|---|---|---|
| [00](phase-00-chuan-bi.md) | Chuẩn bị môi trường & tài khoản | MVP | 0.5 tuần | ⬜ |
| [01](phase-01-walking-skeleton.md) | Walking skeleton (BE + FE + DB thông nhau) | MVP | 1 tuần | ⬜ |
| [02](phase-02-auth.md) | Xác thực & phân quyền | MVP | 1 tuần | ⬜ |
| [03](phase-03-catalog.md) | Catalog: địa điểm, sơ đồ ghế, sự kiện | MVP | 1.5 tuần | ⬜ |
| [04](phase-04-booking.md) | Booking & giữ ghế (chống oversell) | MVP | 1.5 tuần | ⬜ |
| [05](phase-05-payment.md) | Thanh toán Stripe | MVP | 1 tuần | ⬜ |
| [06](phase-06-ticket-notification.md) | Vé QR, email, hoàn vé, check-in | MVP | 1 tuần | ⬜ |
| [07](phase-07-mvp-release.md) | Đóng gói & phát hành MVP (AWS Lab 1) | MVP | 1 tuần | ⬜ |
| [08](phase-08-observability.md) | Observability: metrics, logs (ELK), traces, alert | Vận hành | 1 tuần | ⬜ |
| [09](phase-09-flash-sale.md) | Flash sale: phòng chờ, realtime, rate limit, cache | Vận hành | 1.5 tuần | ⬜ |
| [10](phase-10-load-test.md) | Load test JMeter & tuning (AWS Lab 2) | Vận hành | 1 tuần | ⬜ |
| [11](phase-11-resilience.md) | Resilience & sự cố cơ bản (AWS Lab 3) | Vận hành | 1 tuần | ⬜ |
| [12](phase-12-marketplace-search.md) | Marketplace (Stripe Connect), Search, Dashboard | Kiến trúc | 1.5 tuần | ⬜ |
| [13](phase-13-kafka.md) | Kafka & event-driven | Kiến trúc | 1.5 tuần | ⬜ |
| [14](phase-14-microservices.md) | Tách microservices | Kiến trúc | 2 tuần | ⬜ |
| [15](phase-15-kubernetes.md) | Kubernetes & GitOps | Kiến trúc | 2 tuần | ⬜ |
| [16](phase-16-autoscaling.md) | Autoscaling | Kiến trúc | 1 tuần | ⬜ |
| [17](phase-17-safe-deploy-dr.md) | Deploy an toàn & khôi phục thảm hoạ | Kiến trúc | 1 tuần | ⬜ |
| [18](phase-18-chaos.md) | Chaos engineering & Game Day | Kiến trúc | 1 tuần | ⬜ |
| [19](phase-19-security-hosting.md) | Bảo mật nâng cao & hosting lâu dài | Kiến trúc | 1 tuần | ⬜ |

Trạng thái: ⬜ Chưa bắt đầu · 🟦 Đang làm · ✅ Xong

> Ước lượng giả định ~15–20 giờ/tuần, có Claude hỗ trợ code. Đây là con số định hướng, không phải cam kết.

## 3. Quy tắc làm việc

### R1 — Một step tại một thời điểm
Chỉ làm **1 step**. Step chưa đạt **Kiểm tra (DoD)** thì không sang step tiếp theo.

### R2 — Không nhảy cóc
Không làm việc thuộc phase sau, kể cả khi "tiện tay". Mỗi phase có mục **"Không làm trong phase này"** để nhắc.
Nảy ra ý tưởng / việc của phase sau → ghi vào [backlog.md](backlog.md), làm tiếp step hiện tại.

### R3 — Chưa ưng thì sửa ngay
Review **ngay cuối mỗi step** (không đợi cuối phase). Chưa ưng → sửa luôn trong step đó rồi kiểm tra lại.
Sửa lại một step **đã xong trước đó** là được phép (đó là sửa, không phải nhảy cóc) — ghi chú lại trong file phase.

### R4 — Đổi thiết kế thì cập nhật tài liệu trước
Thay đổi ảnh hưởng thiết kế (thêm thư viện, đổi luồng, đổi bảng dữ liệu…) → cập nhật [overview.md](../docs/overview.md) (+ ADR nếu là quyết định lớn) → cập nhật plan → rồi mới code.

### R5 — Commit theo step, tag theo phase
- Mỗi step = 1 hoặc vài commit, message dạng `feat(booking): giữ ghế bằng Redis Lua (step 4.2)`.
- Theo **Conventional Commits**: `type(scope): mô tả (step N.M)`. `type` ∈ `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `build`; `scope` là module/khu vực (`booking`, `payment`, `infra`, `fe`…).
- Kết thúc phase → tag `phase-04-done`.

### R6 — Mỗi phase bắt đầu bằng Step N.0 (re-plan)
Đọc lại plan của phase, đối chiếu với những gì đã thay đổi ở các phase trước, chỉnh plan nếu cần. Các phase càng xa càng được chi tiết hoá lại kỹ ở bước này.

### R7 — Ngoại lệ duy nhất: mốc AWS theo lịch
AWS credits hết hạn khoảng **10/01/2027**. Xem mục 5.

## 4. Quy trình mỗi step

```
┌────────────┐   ┌───────────┐   ┌──────────────┐   ┌──────────────┐
│ Đọc step   │──▶│ Code      │──▶│ Chạy kiểm tra│──▶│ Bạn review / │
│ (+ Step N.0│   │           │   │ (DoD)        │   │ demo         │
│  nếu đầu   │   └───────────┘   └──────────────┘   └──────┬───────┘
│  phase)    │         ▲                                    │
└────────────┘         │            Chưa ưng → sửa ngay     │
                       └────────────────────────────────────┤
                                                            │ Ưng
                                                            ▼
                                              Tick [x] + commit → step tiếp theo
```

**Giao việc cho Claude:** mỗi lần 1 step, ví dụ: *"Làm Phase 1 · Step 1.3"*.
Claude sẽ: code → chạy kiểm tra trong DoD → báo kết quả → chờ bạn review trước khi sang step tiếp.

## 5. Mốc thời gian AWS

| Mốc | Thời điểm mục tiêu | Thuộc |
|---|---|---|
| AWS Lab 0 — bảo mật tài khoản, budgets, Terraform hello world | ~đầu 11/2026, **trước Lab 1** (hoãn từ Phase 0) | Phase 7 (Step 7.0a) |
| AWS Lab 1 — deploy MVP | ~cuối 11/2026 | Phase 7 |
| AWS Lab 2 — ALB + Auto Scaling Group | ~cuối 12/2026 | Phase 10 |
| AWS Lab 3 — RDS Multi-AZ failover | ~đầu 01/2027 | Phase 11 |
| **Dọn sạch AWS** | **trước 05/01/2027 — cố định** | Không phụ thuộc phase |

**Phương án dự phòng:** nếu đến **20/12/2026** vẫn chưa tới Phase 10 → được phép làm Lab 2 và Lab 3 ngay với bản MVP + 1 kịch bản JMeter đơn giản (ngoại lệ duy nhất của R2). Sau đó quay lại phase đang dở.

## 6. Definition of Done chung (áp dụng cho mọi step)

- [ ] Build & test pass (`./mvnw verify`, `npm run lint && npm test`)
- [ ] Chạy được và kiểm tra bằng tay theo mục **Kiểm tra** của step
- [ ] Không có secret trong code (gitleaks pass)
- [ ] Tài liệu liên quan đã cập nhật (nếu có thay đổi)
- [ ] Đã commit

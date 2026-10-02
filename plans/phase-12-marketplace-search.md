# Phase 12 — Marketplace, Search, Dashboard

> Giai đoạn: **Kiến trúc** · Ước lượng: 1.5 tuần · Phụ thuộc: Phase 11

## Mục tiêu
Hoàn thiện các tính năng nghiệp vụ "nâng cao" đã tạm gác ở MVP: tiền về organizer qua Stripe Connect, tìm kiếm Elasticsearch, dashboard doanh thu jOOQ, audit.

## Kết quả cuối phase
- Organizer kết nối Stripe; mỗi vé bán ra: tiền về organizer, nền tảng giữ 5%.
- Tìm "rock sai gon" ra đúng sự kiện; Elasticsearch sập vẫn tìm được (bản đơn giản).
- Dashboard doanh thu có biểu đồ.

## Không làm trong phase này
- ❌ Kafka (Phase 13) — vẫn dùng event nội bộ Spring Modulith
- ❌ Tách service (Phase 14)

---

## Step 12.0 — Re-plan
- [ ] Đọc lại plan; xem backlog (B1 Organizer Pro, B6 editor sơ đồ) → quyết định đưa vào hay không

## Step 12.1 — Stripe Connect onboarding
- [ ] Bảng `connected_accounts`; tạo Express account + onboarding link
- [ ] Webhook `account.updated` → `charges_enabled`
- [ ] BR-05: publish yêu cầu `charges_enabled` (sửa lại điều kiện tạm của Phase 3)
- [ ] FE: trang kết nối Stripe cho organizer

**Kiểm tra:** organizer hoàn tất onboarding test → được publish.

## Step 12.2 — Destination charge & phí nền tảng
- [ ] PaymentIntent có `transfer_data.destination` + `application_fee_amount`
- [ ] Cấu hình phí nền tảng (Admin) + Hibernate Envers audit
- [ ] Hoàn vé: hoàn tiền, phí nền tảng không hoàn (BR-07)

**Kiểm tra:** Stripe dashboard (test) thấy tiền về connected account, phí về nền tảng.

## Step 12.3 — Tìm kiếm Elasticsearch
- [ ] Index `events` (dùng chung cụm ES với ELK ở dev, index riêng)
- [ ] Projection: nghe `EventPublished/Updated/Cancelled` → index; job reindex toàn bộ
- [ ] Tìm kiếm tiếng Việt không dấu (analyzer `asciifolding`)
- [ ] Fallback Postgres khi ES lỗi + feature flag `search-es`

**Kiểm tra:** "rock sai gon" tìm ra "Đêm nhạc Rock Sài Gòn"; stop ES → vẫn tìm được bằng Postgres.

## Step 12.4 — Dashboard doanh thu (jOOQ)
- [ ] jOOQ codegen từ schema (Flyway → Testcontainers → codegen)
- [ ] API: doanh thu theo ngày, tỉ lệ lấp đầy theo hạng vé
- [ ] FE: Recharts (shadcn Charts)

**Kiểm tra:** số liệu dashboard khớp truy vấn kiểm tra thủ công.

## Step 12.5 — Admin: audit log
- [ ] Trang xem lịch sử thay đổi (Envers) và thao tác quản trị

**Kiểm tra:** đổi phí nền tảng → thấy ai đổi, lúc nào, giá trị cũ / mới.

## Step 12.6 — Đa ngôn ngữ
- [ ] react-i18next (vi/en) cho FE; template email 2 ngôn ngữ

**Kiểm tra:** đổi ngôn ngữ toàn bộ giao diện.

---

## Checklist kết thúc phase
- [ ] Tag `phase-12-done`

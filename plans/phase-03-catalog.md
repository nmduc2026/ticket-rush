# Phase 3 — Catalog: địa điểm, sơ đồ ghế, sự kiện

> Giai đoạn: **MVP** · Ước lượng: 1.5 tuần · Phụ thuộc: Phase 2

## Mục tiêu
Admin tạo địa điểm & sơ đồ ghế; organizer được duyệt rồi tạo và publish sự kiện; khách xem danh sách / chi tiết sự kiện.

## Kết quả cuối phase
- Có 1 địa điểm mẫu ~500 ghế, 3 khu, hiển thị bằng react-konva.
- Organizer tạo sự kiện 2 hạng vé, publish thành công.
- Khách (chưa đăng nhập) tìm và xem được sự kiện.

## Không làm trong phase này
- ❌ Tồn kho ghế theo sự kiện, giữ ghế, chọn ghế (Phase 4) — sơ đồ ở phase này chỉ **xem**
- ❌ Kiểm tra Stripe Connect khi publish (Phase 12) — tạm thời chỉ cần organizer đã được duyệt
- ❌ Elasticsearch (Phase 12) — tìm kiếm bằng Postgres
- ❌ Editor sơ đồ kéo thả (backlog B6) — dùng bộ sinh dạng lưới
- ❌ Dashboard doanh thu (Phase 12)

---

## Step 3.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 3.1 — Địa điểm & sơ đồ ghế (BE)
- [ ] Entity + Flyway: `administrative_units` (1 bảng, `level` 1/2 + `parent_id`, CHECK cấp), `venues` (`ward_id` → cấp xã), `seat_maps`, `sections`, `seats`
- [ ] Seed đơn vị hành chính 2 cấp (34 tỉnh/thành + xã/phường) từ file Excel danh mục mã; API công khai `GET /administrative-units` có cache
- [ ] API sinh khu ghế dạng lưới: số hàng × số ghế/hàng, vị trí gốc, khoảng cách → tự tính `x, y`
- [ ] CRUD API cho Admin (`/api/v1/admin/venues`, `/admin/seat-maps`, `/admin/administrative-units`)
- [ ] Import Excel dùng chung (Apache POI): tải file mẫu, `dryRun` trả lỗi theo dòng–cột, ghi các dòng hợp lệ, file lỗi `.xlsx`; áp dụng cho đơn vị hành chính, địa điểm, sơ đồ ghế
- [ ] Integration test

**Kiểm tra:** tạo sơ đồ 3 khu qua Swagger, số ghế đúng như tính toán.

## Step 3.2 — Địa điểm & sơ đồ ghế (FE Admin)
- [ ] Danh sách địa điểm (shadcn Data Table), form tạo/sửa (React Hook Form + Zod), chọn Tỉnh/TP → Xã/Phường
- [ ] Màn Đơn vị hành chính (prototype màn 33) + modal Import Excel 3 bước dùng chung cho 3 màn
- [ ] Form sinh khu ghế + **xem trước bằng react-konva** (zoom/pan, chỉ xem)

**Kiểm tra:** tạo "địa điểm mẫu" 500 ghế bằng UI, xem sơ đồ mượt.

## Step 3.3 — Organizer onboarding
- [ ] Bảng `organizers`; API `POST /organizer/apply`, `POST /admin/organizers/{id}/approve`
- [ ] Gán role `ORGANIZER` trong Keycloak khi duyệt: thêm client `ticketrush-internal` (service account) + thư viện **Keycloak Admin Client** → cập nhật overview (R4)
- [ ] FE: trang đăng ký organizer, trang Admin duyệt

**Kiểm tra:** user A đăng ký → admin duyệt → A đăng nhập lại thấy menu Organizer.

## Step 3.4 — Sự kiện & hạng vé (BE)
- [ ] Entity + Flyway: `events`, `ticket_tiers`, `tier_sections`; `@Version` cho events
- [ ] API organizer: tạo/sửa sự kiện nháp, hạng vé, gán hạng vé cho khu ghế
- [ ] **Kiểm tra quyền sở hữu**: organizer B không sửa được sự kiện của A
- [ ] Thêm **MinIO** vào Compose; upload banner bằng presigned URL

**Kiểm tra:** integration test: B sửa sự kiện của A → 403/404; 2 request sửa cùng lúc → 1 cái nhận lỗi xung đột (409).

## Step 3.5 — Vòng đời sự kiện
- [ ] State machine: `DRAFT → PUBLISHED → ON_SALE → SOLD_OUT/ENDED`, `CANCELLED`
- [ ] Điều kiện publish: organizer đã duyệt, mọi khu ghế đều có hạng vé, `sale_starts_at` hợp lệ
- [ ] Publish phát event nội bộ `EventPublished` (Spring Modulith) — **chưa có ai nghe**, Phase 4 mới dùng
- [ ] Unit test state machine

**Kiểm tra:** test chuyển trạng thái hợp lệ / không hợp lệ đều pass.

## Step 3.6 — FE Organizer: quản lý sự kiện
- [ ] Danh sách sự kiện của tôi, form tạo/sửa (nhiều bước: thông tin → địa điểm → hạng vé → banner), nút publish

**Kiểm tra:** organizer tạo và publish 1 sự kiện hoàn toàn bằng UI.

## Step 3.7 — FE công khai: xem sự kiện
- [ ] API `GET /api/v1/events` lọc theo từ khoá (ILIKE), thành phố, khoảng ngày; phân trang
- [ ] Trang chủ, trang danh sách, trang chi tiết (banner, mô tả, bảng giá, sơ đồ chỉ xem)

**Kiểm tra:** chưa đăng nhập vẫn tìm và xem được sự kiện; sự kiện DRAFT không hiện ra.

---

## Checklist kết thúc phase
- [ ] Demo: admin tạo địa điểm → organizer tạo & publish → khách xem
- [ ] Seed data mẫu (script) để các phase sau dùng
- [ ] Tag `phase-03-done`

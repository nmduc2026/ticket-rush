# Phase 4 — Booking & giữ ghế

> Giai đoạn: **MVP** · Ước lượng: 1.5 tuần · Phụ thuộc: Phase 3

## Mục tiêu
Phần cốt lõi của hệ thống: khách chọn ghế, hệ thống giữ ghế 10 phút và **tuyệt đối không bán trùng** (3 lớp phòng thủ — [overview §10](../overview.md#10-chống-oversell-concurrency)).

## Kết quả cuối phase
- 2 trình duyệt cùng chọn 1 ghế → chỉ 1 người giữ được.
- Test 200 luồng tranh 50 ghế → đúng 50 booking.
- Hết 10 phút không thanh toán → ghế tự nhả.

## Không làm trong phase này
- ❌ Thanh toán (Phase 5) — booking dừng ở `PENDING_PAYMENT`
- ❌ Cập nhật realtime bằng SSE (Phase 9) — tạm dùng **polling** 5 giây
- ❌ Phòng chờ, semaphore, rate limit (Phase 9)
- ❌ Load test JMeter (Phase 10) — chỉ dùng integration test đa luồng

---

## Step 4.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 4.1 — Tồn kho ghế theo sự kiện
- [ ] Bảng `seat_inventory` (Flyway)
- [ ] Nghe `EventPublished` → tạo dòng tồn kho cho mọi ghế (AVAILABLE, giá theo hạng vé)
- [ ] `GET /api/v1/events/{id}/seats` → sơ đồ + trạng thái

**Kiểm tra:** publish sự kiện 500 ghế → 500 dòng tồn kho; publish lại không tạo trùng (idempotent).

## Step 4.2 — Giữ ghế bằng Redis (lớp 1)
- [ ] Thiết kế key theo [overview §9](../overview.md#9-thiết-kế-redis) (hash tag `{eventId}`)
- [ ] Lua script giữ nhiều ghế atomic + nhả ghế
- [ ] Testcontainers Redis

**Kiểm tra:** integration test: 2 lệnh giữ cùng ghế song song → đúng 1 thành công; giữ [A1, A2] khi A2 bận → không giữ ghế nào.

## Step 4.3 — Tạo booking (lớp 2 + 3)
- [ ] Bảng `bookings`, `booking_items`, unique index "1 booking chờ / user / sự kiện"
- [ ] `POST /api/v1/bookings`: kiểm tra BR-02 → Lua giữ ghế → `UPDATE seat_inventory ... WHERE status='AVAILABLE'` (lệch số dòng → rollback + nhả Redis) → booking `PENDING_PAYMENT`, `expires_at`
- [ ] Header `Idempotency-Key`: gửi lại cùng key → trả lại booking cũ
- [ ] Mã lỗi: `SEAT_UNAVAILABLE`, `TOO_MANY_SEATS`, `PENDING_BOOKING_EXISTS`, `EVENT_NOT_ON_SALE`
- [ ] Phát event nội bộ `BookingCreated` (chưa ai nghe — Phase 5)

**Kiểm tra:** integration test cho từng mã lỗi + idempotency.

## Step 4.4 — Hết hạn & huỷ booking
- [ ] Job `ExpireBookings` (`@Scheduled` + **ShedLock**) mỗi 30s: booking quá hạn → `EXPIRED`, nhả ghế (DB + Redis), phát `BookingExpired`
- [ ] User tự huỷ booking đang chờ
- [ ] Dùng bean `Clock` để test không phải chờ 10 phút

**Kiểm tra:** test với Clock giả: tiến thời gian 11 phút → booking EXPIRED, ghế AVAILABLE.

## Step 4.5 — Kiểm chứng chống oversell
- [ ] Integration test: 200 virtual thread cùng đặt ngẫu nhiên trên 50 ghế
- [ ] Truy vấn bất biến (overview §10) trả 0 dòng
- [ ] Ghi kết quả vào `docs/` (số liệu đầu tiên cho portfolio)

**Kiểm tra:** test pass ổn định khi chạy 10 lần liên tiếp.

## Step 4.6 — FE chọn ghế
- [ ] react-konva tương tác: zoom/pan, màu theo hạng vé & trạng thái, click chọn (tối đa 6), tooltip giá
- [ ] Zustand store ghế đang chọn; panel tóm tắt (ghế, tổng tiền)
- [ ] Tạo booking (Idempotency-Key sinh 1 lần cho mỗi lần bấm), xử lý 409 → làm mới sơ đồ + toast
- [ ] Polling trạng thái ghế 5 giây/lần

**Kiểm tra:** 2 trình duyệt (2 user) cùng chọn ghế A5 → người thứ 2 nhận thông báo, sơ đồ cập nhật.

## Step 4.7 — FE checkout (khung) & đơn của tôi
- [ ] `/checkout/:bookingId`: thông tin đơn, **đồng hồ đếm ngược**, nút huỷ; nút thanh toán để trạng thái "sắp có" (Phase 5)
- [ ] `/me/bookings`: danh sách đơn + trạng thái
- [ ] Hết giờ → thông báo + quay lại chọn ghế

**Kiểm tra:** demo trọn luồng chọn ghế → checkout → chờ hết hạn → ghế được nhả trên sơ đồ.

---

## Checklist kết thúc phase
- [ ] Demo 2 trình duyệt tranh ghế
- [ ] Tag `phase-04-done`

# Phase 5 — Thanh toán Stripe

> Giai đoạn: **MVP** · Ước lượng: 1 tuần · Phụ thuộc: Phase 4

## Mục tiêu
Thanh toán bằng Stripe (test mode) với webhook, idempotency, và đầy đủ các nhánh bù trừ của Saga.

## Kết quả cuối phase
- Thanh toán bằng thẻ `4242 4242 4242 4242` → booking `CONFIRMED`, ghế `SOLD`.
- Thẻ bị từ chối → thông báo lỗi, được thử lại trong thời gian giữ ghế.
- Webhook gửi lặp 3 lần → chỉ xử lý 1 lần.

## Không làm trong phase này
- ❌ Stripe Connect / tiền về organizer / phí nền tảng (Phase 12) — tiền về tài khoản nền tảng
- ❌ Phát hành vé, gửi email, hoàn vé (Phase 6)
- ❌ Circuit breaker / retry Resilience4j (Phase 11) — chỉ đặt timeout cơ bản
- ❌ Vault (Phase 15) — Stripe key để trong `.env`

---

## Step 5.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 5.1 — Chuẩn bị
- [ ] Tạo tài khoản Stripe test mode (hoãn từ Step 0.6): quốc gia hỗ trợ merchant (vd. Singapore), `stripe login`, thử tạo PaymentIntent VND (`stripe payment_intents create --amount=50000 --currency=vnd`) để xác nhận charge được VND
- [ ] `stripe-java`; key test trong `.env`
- [ ] Bảng `payable_bookings`, `payments`, `stripe_events` (Flyway)
- [ ] Nghe `BookingCreated` → lưu `payable_bookings` (projection, module payment không đọc bảng của booking)

**Kiểm tra:** tạo booking → có dòng tương ứng trong `payable_bookings`.

## Step 5.2 — Tạo PaymentIntent
- [ ] `POST /api/v1/payments {bookingId}`: kiểm tra chủ đơn, còn hạn; tạo PaymentIntent với idempotency key `booking-{id}`, metadata `bookingId`; trả `clientSecret`
- [ ] Test bằng WireMock (giả Stripe API)

**Kiểm tra:** gọi 2 lần → cùng 1 PaymentIntent.

## Step 5.3 — Webhook
- [ ] `POST /api/v1/webhooks/stripe` (bỏ qua auth/CSRF, **bắt buộc verify chữ ký**)
- [ ] Lưu `stripe_events` (khoá chính = event id) → trùng thì bỏ qua
- [ ] State machine payment chỉ cho chuyển tiến; xử lý `payment_intent.succeeded` / `payment_failed`
- [ ] Phát `PaymentSucceeded` / `PaymentFailed`

**Kiểm tra:** `stripe listen --forward-to ...` + `stripe trigger payment_intent.succeeded`; gửi lại event cũ (`stripe events resend`) → không xử lý lần 2; payload sửa tay → 400.

## Step 5.4 — Xác nhận booking & các nhánh bù trừ
- [ ] Nghe `PaymentSucceeded` → `HELD → SOLD`, booking `CONFIRMED`, phát `BookingConfirmed`
- [ ] Nghe `BookingExpired` → huỷ PaymentIntent
- [ ] Thanh toán đến muộn (booking đã EXPIRED): giữ lại được ghế → CONFIRMED; không được → `BookingConfirmationFailed` → **hoàn tiền tự động**
- [ ] Integration test cho cả 3 nhánh

**Kiểm tra:** 3 test pass.

## Step 5.5 — FE thanh toán
- [ ] `@stripe/react-stripe-js` + Payment Element trên trang checkout
- [ ] `confirmPayment` → trang kết quả: polling trạng thái booking đến khi `CONFIRMED` / lỗi
- [ ] Xử lý: thẻ bị từ chối, hết giờ giữa chừng, đóng tab rồi quay lại

**Kiểm tra:** trên trình duyệt: thẻ `4242...` thành công; thẻ `4000 0000 0000 9995` bị từ chối rồi thử lại thẻ đúng → thành công.

## Step 5.6 — Đối soát
- [ ] Job (ShedLock): payment `PROCESSING` quá 15 phút → hỏi trạng thái trực tiếp Stripe API → cập nhật

**Kiểm tra:** tắt `stripe listen` khi thanh toán → bật job → booking vẫn được xác nhận.

---

## Checklist kết thúc phase
- [ ] Demo trọn luồng chọn ghế → trả tiền → CONFIRMED
- [ ] Tag `phase-05-done`

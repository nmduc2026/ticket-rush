# Phase 6 — Vé QR, email, hoàn vé, check-in

> Giai đoạn: **MVP** · Ước lượng: 1 tuần · Phụ thuộc: Phase 5

## Mục tiêu
Hoàn thiện vòng đời của vé: phát hành QR ký số, gửi email, hoàn vé, check-in tại cổng.

## Kết quả cuối phase
- Mua vé xong → email (Mailpit) có mã QR; vé hiện trong "Vé của tôi".
- Quét QR bằng điện thoại → hợp lệ; quét lần 2 → "đã sử dụng".
- Hoàn vé → tiền hoàn (Stripe), vé bị thu hồi, ghế mở bán lại.

## Không làm trong phase này
- ❌ Vault & xoay vòng khoá ký (Phase 15) — khoá để trong file cấu hình local
- ❌ Gửi email thật qua SES (Phase 7 nếu cần)
- ❌ Đa ngôn ngữ email (Phase 12)

---

## Step 6.0 — Re-plan
- [ ] Đọc lại plan, xem backlog

## Step 6.1 — Phát hành vé
- [ ] Bảng `tickets`, `signing_keys`; unique `(event_id, seat_id)` cho vé chưa thu hồi (lớp phòng thủ 3)
- [ ] Sinh cặp khoá EC P-256 cho local; Nimbus JOSE ký JWT ES256 kèm `kid`
- [ ] Nghe `BookingConfirmed` → tạo vé cho từng ghế → phát `TicketIssued`
- [ ] `GET /api/v1/me/tickets`

**Kiểm tra:** integration test: booking 2 ghế → 2 vé, mỗi QR verify được bằng public key.

## Step 6.2 — Email
- [ ] Thêm **Mailpit** vào Compose `core`
- [ ] Spring Mail + Thymeleaf: template "đặt vé thành công" (ảnh QR sinh bằng ZXing), "hoàn tiền thành công"
- [ ] Bảng `notification_log`; nghe `TicketIssued`

**Kiểm tra:** mua vé → email trong Mailpit (`localhost:8025`) có QR quét được.

## Step 6.3 — FE vé của tôi
- [ ] `/me/tickets`: danh sách theo sự kiện; chi tiết vé hiển thị QR (`qrcode.react`), thông tin ghế
- [ ] Hiển thị tốt trên điện thoại (dùng để đưa quét tại cổng)

**Kiểm tra:** mở trên điện thoại (cùng mạng LAN) xem được QR.

## Step 6.4 — Hoàn vé
- [ ] `POST /bookings/{id}/refund`: kiểm tra BR-07 (≥ 48h trước giờ diễn) → `REFUND_REQUESTED`
- [ ] Stripe Refund (idempotency key `refund-{bookingId}`), webhook `charge.refunded` → `RefundCompleted`
- [ ] Booking `REFUNDED`, ghế `AVAILABLE` (DB + Redis), vé `REVOKED`, email xác nhận
- [ ] FE: nút hoàn vé + dialog xác nhận

**Kiểm tra:** hoàn vé → ghế xuất hiện lại trên sơ đồ, QR cũ bị từ chối khi check-in.

## Step 6.5 — Huỷ sự kiện → hoàn tiền hàng loạt
- [ ] Organizer huỷ sự kiện (BR-08) → job hoàn tiền từng booking (idempotent, chạy lại an toàn nếu dừng giữa chừng)

**Kiểm tra:** sự kiện có 5 booking → huỷ → 5 refund, chạy lại job không tạo refund trùng.

## Step 6.6 — Check-in
- [ ] `GET /api/v1/tickets/keys` (public key dạng JWKS) cho máy quét
- [ ] `POST /api/v1/checkins`: `UPDATE ... WHERE status='VALID'`; chỉ organizer chủ sự kiện
- [ ] FE `/checkin/:eventId`: quét camera (`@yudiel/react-qr-scanner`), verify chữ ký offline bằng thư viện **`jose`** (npm) → cập nhật overview (R4); phản hồi xanh/đỏ + âm thanh

**Kiểm tra:** dùng điện thoại quét QR trên màn hình laptop: lần 1 xanh, lần 2 đỏ "đã sử dụng"; QR tự chế (ký bằng khoá khác) → đỏ "vé giả".

---

## Checklist kết thúc phase
- [ ] Demo trọn vòng đời: mua → email → check-in → (mua khác) → hoàn
- [ ] Tag `phase-06-done`

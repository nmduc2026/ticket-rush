# TicketRush — Thiết kế giao diện (prototype)

> Prototype tương tác (xem & bấm thử): **https://claude.ai/artifact/13t7cm5BAqJ63AZa18fDgU**
> Mã nguồn từng màn: [prototype/](prototype/) — mỗi file `*.dc.html` là 1 màn hình.
> Thiết kế hệ thống: [overview.md](../overview.md) · Kế hoạch: [plans/](../../plans/README.md)

## 1. Cách dùng tài liệu này

- Đây là **bản tham chiếu giao diện** khi code FE (React + shadcn). Không copy nguyên file `.dc.html` vào code — chúng chạy trên runtime riêng của canvas, không phải React.
- Khi code một màn: mở prototype → bấm **Play** để xem hành vi → đối chiếu bảng màn hình (mục 4) để biết route, component shadcn cần dùng và phase thực hiện.
- Muốn sửa thiết kế: sửa trên canvas trước (hoặc nhờ Claude), rồi chép lại file vào `prototype/` — giữ prototype là nguồn sự thật về giao diện.

## 2. Theme (shadcn — Emerald)

Dán vào `src/index.css` (Tailwind v4 + shadcn). Chỉ dùng chế độ sáng ở giai đoạn đầu.

```css
:root {
  --radius: 0.625rem;

  --background: #FFFFFF;
  --foreground: #09090B;
  --card: #FFFFFF;
  --card-foreground: #09090B;
  --popover: #FFFFFF;
  --popover-foreground: #09090B;

  --primary: #047857;              /* emerald-700 — nền nút, chữ trắng đạt 5.5:1 */
  --primary-foreground: #FFFFFF;
  --secondary: #F4F4F5;
  --secondary-foreground: #18181B;
  --muted: #F4F4F5;
  --muted-foreground: #71717A;
  --accent: #F4F4F5;               /* hover của ghost button, menu item */
  --accent-foreground: #18181B;
  --destructive: #DC2626;
  --border: #E4E4E7;
  --input: #E4E4E7;
  --ring: #34D399;

  --chart-1: #059669;
  --chart-2: #0891B2;
  --chart-3: #F59E0B;
  --chart-4: #7C3AED;
  --chart-5: #E11D48;

  --sidebar: #FAFAFA;
  --sidebar-foreground: #3F3F46;
  --sidebar-primary: #059669;
  --sidebar-primary-foreground: #FFFFFF;
  --sidebar-accent: #ECFDF5;       /* mục đang active */
  --sidebar-accent-foreground: #065F46;
  --sidebar-border: #E4E4E7;
  --sidebar-ring: #34D399;
}
```

| Token phụ | Giá trị | Dùng cho |
|---|---|---|
| `emerald-600` `#059669` | Đồ hoạ không có chữ | Thanh biểu đồ, progress, checkbox, logo, ghế được chọn trên sơ đồ admin |
| `emerald-50` `#ECFDF5` / `emerald-800` `#065F46` | Nền nhạt + chữ | Chip bộ lọc, toggle đang chọn, banner gợi ý |
| `emerald-100` `#D1FAE5` | Avatar | Avatar chữ cái |
| Trạng thái | xanh `#16A34A` · vàng `#F59E0B` · xanh dương `#2563EB` · xám `#52525B` / `#A1A1AA` · đỏ `#DC2626` | Chấm màu trong badge trạng thái |
| Hạng vé | VIP `#9A3412` · Standard `#EA580C` · Phổ thông `#F59E0B` | Màu ghế theo hạng (chọn được khi tạo hạng vé) |

**Typography**: `Be Vietnam Pro` (400/500/600/700) cho toàn bộ UI — hiển thị tiếng Việt tốt; `Oswald` 600 chỉ dùng cho chữ trên poster sự kiện. Cỡ chữ nền 14px; tiêu đề trang 24px/600; số liệu dùng `font-variant-numeric: tabular-nums`.

## 3. Quy ước giao diện

| Quy ước | Chi tiết | Component shadcn |
|---|---|---|
| **Layout khách hàng** | Header 64px (logo · ô tìm kiếm · Tạo sự kiện · Vé của tôi · avatar) + hàng danh mục; footer sáng | — |
| **Layout Organizer / Admin** | Theo **sidebar-07**: team switcher · menu nhóm có mục con thu gọn · "Sự kiện gần đây" · user ở cuối; header có `SidebarTrigger` + breadcrumb | `Sidebar`, `Collapsible`, `Breadcrumb`, `DropdownMenu` |
| **Mọi màn danh sách** | Ô tìm kiếm + bộ lọc dạng facet (chọn nhiều, có đếm) + nút "Đặt lại" + bảng + phân trang (số dòng/trang, Trang x/y, « ‹ › ») | Data Table (`@tanstack/react-table`), `Popover` + `Command`, `Pagination` |
| **Thao tác** | Mọi thao tác (tạo / sửa / xoá / duyệt / hoàn tiền…) mở **modal**; thao tác phá huỷ dùng nút đỏ + câu xác nhận rõ hậu quả | `Dialog`, `AlertDialog`; mobile dùng `Drawer` |
| **Menu dòng** | Nút `⋯` cuối mỗi dòng → menu; mục nguy hiểm màu đỏ, ngăn cách bằng separator | `DropdownMenu` |
| **Import Excel** | Màn danh mục có 2 nút cạnh nút Thêm: **Tải file mẫu** và **Import Excel**. Modal 3 bước: Chọn file (.xlsx/.csv, ≤ 5 MB, ≤ 5.000 dòng, chọn khi trùng mã: cập nhật / bỏ qua, bảng cột của file mẫu) → Kiểm tra (dry-run: tổng / hợp lệ / lỗi theo dòng–cột, tải file lỗi) → Kết quả (thêm mới / cập nhật / bỏ qua, ghi audit log). Dòng lỗi không chặn dòng hợp lệ | `Dialog`, `Table`, `Alert` |
| **Badge trạng thái** | Viền mảnh + chấm màu + chữ (không dùng nền pastel) | `Badge variant="outline"` |
| **Trường bắt buộc** | Dấu `*` đỏ nằm **cùng dòng** với nhãn (`Tên sự kiện *`); gợi ý ngắn đặt dưới ô nhập | `Label` + `FormDescription` |
| **Giọng văn** | Nhãn và trạng thái ngắn, đọc là hiểu: "Chưa kết nối", "Khoá sau khi publish", "Hiệu lực 24 giờ". Không viết giọng hướng dẫn hay quảng cáo ("Kết nối Stripe để nhận tiền…", "Bạn muốn…?", "Hãy…", "Vui lòng…"). Mô tả dưới tiêu đề trang chỉ dùng khi có thông tin thật (ngày giờ, nguồn dữ liệu) | — |
| **Poster sự kiện** | Khi chưa có ảnh: nền màu + khối tròn + chữ Oswald (tỉ lệ 16:9) | — |

## 4. Danh sách màn hình

| # | Màn hình | File | Route (FE) | Phase |
|---|---|---|---|---|
| 1 | Trang chủ | [Main](prototype/Main.dc.html) | `/` | 3 |
| 2 | Danh sách sự kiện (lọc + phân trang) | [EventList](prototype/EventList.dc.html) | `/events` | 3 |
| 3 | Chi tiết sự kiện | [EventDetail](prototype/EventDetail.dc.html) | `/events/:id` | 3 |
| 4 | Hàng chờ trực tuyến | [Queue](prototype/Queue.dc.html) | `/events/:id/queue` | 9 |
| 5 | Chọn ghế | [SeatSelect](prototype/SeatSelect.dc.html) | `/events/:id/seats` | 4 (SSE ở 9) |
| 6 | Thanh toán | [Checkout](prototype/Checkout.dc.html) | `/checkout/:bookingId` | 4 → 5 |
| 7 | Thanh toán thành công | [Success](prototype/Success.dc.html) | `/checkout/:bookingId/success` | 5 |
| 8 | Vé của tôi (mobile) | [MyTickets](prototype/MyTickets.dc.html) | `/me/tickets` | 6 |
| 9 | Chi tiết vé QR + hoàn vé | [TicketQR](prototype/TicketQR.dc.html) | `/me/tickets/:id` | 6 |
| 10 | Check-in tại cổng | [Checkin](prototype/Checkin.dc.html) | `/checkin/:eventId` | 6 |
| 11 | Organizer — Tổng quan | [OrgDashboard](prototype/OrgDashboard.dc.html) | `/organizer` | 7 (biểu đồ ở 12) |
| 12 | Organizer — Sự kiện | [OrgEvents](prototype/OrgEvents.dc.html) | `/organizer/events` | 3 |
| 13 | Organizer — Sửa sự kiện: hạng vé | [OrgCreateEvent](prototype/OrgCreateEvent.dc.html) | `/organizer/events/:id/tiers` | 3 |
| 14 | Organizer — Đơn hàng | [OrgOrders](prototype/OrgOrders.dc.html) | `/organizer/orders` | 7 |
| 15 | Admin — Hồ sơ organizer | [AdminOrganizers](prototype/AdminOrganizers.dc.html) | `/admin/organizers` | 3 |
| 16 | Admin — Địa điểm (+ import Excel) | [AdminVenues](prototype/AdminVenues.dc.html) | `/admin/venues` | 3 |
| 17 | Admin — Sơ đồ ghế (+ import Excel) | [AdminSeatMap](prototype/AdminSeatMap.dc.html) | `/admin/venues/:id/seat-maps/:mapId` | 3 |
| 18 | Đăng nhập / Đăng ký / Xác minh / Quên & đặt lại mật khẩu (theme Keycloak) | [Auth](prototype/Auth.dc.html) | Keycloak realm `ticketrush` | 2 |
| 19 | Hồ sơ cá nhân · Bảo mật · Cài đặt thông báo | [Profile](prototype/Profile.dc.html) | `/me/profile` | 2 (thông báo ở 6) |
| 20 | Thông báo (+ popover chuông ở header) | [Notifications](prototype/Notifications.dc.html) | `/me/notifications` | 6 |
| 21 | Đơn hàng của tôi | [MyBookings](prototype/MyBookings.dc.html) | `/me/bookings` | 4 → 6 |
| 22 | Đăng ký làm ban tổ chức (form · chờ duyệt · bị từ chối · đã duyệt) | [OrganizerApply](prototype/OrganizerApply.dc.html) | `/organizer/apply` | 3 |
| 23 | Trạng thái lỗi & ngoại lệ (404, 403, hết giờ giữ ghế, thanh toán lỗi…) | [SystemStates](prototype/SystemStates.dc.html) | — (dùng chung) | 4 → 9 |
| 24 | Organizer — Sửa sự kiện: thông tin · mở bán · phòng chờ | [OrgEventInfo](prototype/OrgEventInfo.dc.html) | `/organizer/events/:id/edit` | 3 (phòng chờ ở 9) |
| 25 | Organizer — Bảng điều khiển sự kiện | [OrgEventSales](prototype/OrgEventSales.dc.html) | `/organizer/events/:id/dashboard` | 7 (realtime ở 12) |
| 26 | Organizer — Thanh toán & Stripe | [OrgStripe](prototype/OrgStripe.dc.html) | `/organizer/payments` | 12 |
| 27 | Organizer — Cài đặt (hồ sơ, thành viên, thông báo, pháp lý) | [OrgSettings](prototype/OrgSettings.dc.html) | `/organizer/settings` | 7 (thành viên: backlog) |
| 28 | Admin — Người dùng | [AdminUsers](prototype/AdminUsers.dc.html) | `/admin/users` | 7 |
| 29 | Admin — Đơn hàng & hoàn tiền (đối soát) | [AdminOrders](prototype/AdminOrders.dc.html) | `/admin/orders` | 6 (đối soát ở 11) |
| 30 | Admin — Phí nền tảng | [AdminFees](prototype/AdminFees.dc.html) | `/admin/fees` | 12 |
| 31 | Admin — Audit log | [AdminAuditLogs](prototype/AdminAuditLogs.dc.html) | `/admin/audit-logs` | 12 |
| 32 | Admin — Feature flags | [AdminFlags](prototype/AdminFlags.dc.html) | `/admin/feature-flags` | 9 |
| 33 | Admin — Đơn vị hành chính (Tỉnh/TP → Xã/Phường, + import Excel) | [AdminRegions](prototype/AdminRegions.dc.html) | `/admin/administrative-units` | 3 |

> **Hành vi từng nút**: trên canvas, dưới mỗi màn có một ghi chú vàng “HÀNH ĐỘNG — …” liệt kê mọi nút/link, điều hướng đi đâu, mở modal gì, và trạng thái nào bị khoá.
>
> Prototype vẽ theo **bản hoàn chỉnh**. Khi làm ở phase sớm hơn, phần chưa tới phase thì để trống hoặc ẩn (vd. Phase 4 chưa có SSE → sơ đồ ghế dùng polling; chưa có Stripe Connect → ẩn mục "Thanh toán & Stripe").

## 5. Modal có trong prototype

Xem trên canvas: mở **Tweaks → dialog** của màn tương ứng, hoặc bấm **Play** rồi thao tác.

| Màn | Modal |
|---|---|
| Organizer — Sự kiện | Tạo sự kiện mới · Huỷ sự kiện (xác nhận bằng chữ "HUY") |
| Organizer — Sửa sự kiện | Thêm / sửa hạng vé (chọn màu, khu áp dụng) · Xoá hạng vé · Chưa thể publish |
| Organizer — Đơn hàng | Hoàn tiền đơn (lý do, ghi chú, gửi email) |
| Admin — Hồ sơ organizer | Xem hồ sơ · Duyệt · Từ chối (lý do bắt buộc) · Tạm khoá |
| Admin — Địa điểm | Thêm / sửa địa điểm (Tỉnh/TP → Xã/Phường lấy từ danh mục) · Xoá địa điểm · Import Excel |
| Admin — Sơ đồ ghế | Thêm / sửa khu ghế (sinh lưới) · Xoá khu · Import Excel |
| Vé QR (mobile) | Bottom sheet hoàn vé |
| Hồ sơ cá nhân | Đổi email · Đổi mật khẩu · Đăng xuất thiết bị khác · Xoá tài khoản (gõ email xác nhận) |
| Đơn hàng của tôi | Chi tiết đơn (vé, thanh toán, lịch sử) · Yêu cầu hoàn vé · Đã quá hạn hoàn vé (< 48h) · Huỷ giữ chỗ |
| Đăng ký ban tổ chức | Xác nhận gửi hồ sơ · Rút hồ sơ |
| Organizer — Sửa sự kiện: thông tin | Publish (xác nhận) · Chưa thể publish → Kết nối Stripe · Đổi sơ đồ ghế (cảnh báo mất gán hạng vé) |
| Organizer — Bảng điều khiển sự kiện | Tạm dừng bán · Huỷ sự kiện (lý do + "HUY") |
| Organizer — Thanh toán & Stripe | Mở trang Stripe / Tiếp tục hồ sơ trên Stripe · Không thể ngắt kết nối |
| Organizer — Cài đặt | Mời thành viên / Đổi vai trò · Xoá thành viên · Yêu cầu cập nhật pháp lý |
| Admin — Người dùng | Chi tiết người dùng · Đổi vai trò · Khoá tài khoản |
| Admin — Đơn hàng & hoàn tiền | Chi tiết + dòng thời gian Stripe · Hoàn tiền thủ công (tuỳ chọn hoàn cả phí) · Xử lý đối soát |
| Admin — Phí nền tảng | Đổi mức mặc định · Thêm / sửa mức riêng · Xoá mức riêng |
| Admin — Audit log | Chi tiết (so sánh trước / sau) |
| Admin — Feature flags | Bật/tắt flag quan trọng (nhập lý do) · Tạo / sửa flag · Lưu trữ flag |
| Admin — Đơn vị hành chính | Thêm / sửa đơn vị (chọn cấp 1/2, thuộc tỉnh/thành) · Ngừng sử dụng · Không xoá được (còn đơn vị con hoặc địa điểm) · Xoá · Import Excel |

Màn **Đăng nhập** (Tweaks → mode), **Trạng thái lỗi** (Tweaks → state), **Đăng ký ban tổ chức** (Tweaks → status), **Thanh toán & Stripe** (Tweaks → state) có nhiều trạng thái màn hình, chọn trong Tweaks hoặc thao tác khi Play.

> Nút và modal chỉ phản hồi khi bấm **Play** trên artboard. Ở chế độ chỉnh sửa canvas, click chỉ chọn phần tử.

### Luồng kết nối Stripe (màn 26)

| Trạng thái | `state` | Hiển thị | Hành động |
|---|---|---|---|
| Chưa kết nối | `none` | Cảnh báo BR-05 · điều khoản (phí 5%, phí thẻ, lịch rút, giấy tờ) | **Kết nối Stripe** → modal "Mở trang Stripe" → **Mở Stripe**: BE gọi `POST /organizer/stripe/onboarding-link` (tạo Express account nếu chưa có) rồi redirect |
| Đang ở trang Stripe | `redirect` | Khung nét đứt = mô phỏng trang onboarding trên stripe.com | Hoàn tất → `pending` · Thoát giữa chừng → `incomplete` · Link hết hạn → `incomplete` (bấm lại sẽ tạo link mới) |
| Hồ sơ chưa hoàn tất | `incomplete` | Danh sách mục còn thiếu | **Tiếp tục trên Stripe** → modal → trang Stripe |
| Đang xác minh | `pending` | Hồ sơ đã gửi, trạng thái từng mục | **Làm mới trạng thái**. Trạng thái thật cập nhật qua webhook `account.updated` (khung mô phỏng: xác minh xong → `active`, yêu cầu bổ sung → `incomplete`) |
| Đã kết nối | `active` | `charges_enabled` + `payouts_enabled` · số dư · doanh thu & phí theo sự kiện · lịch sử rút tiền | **Stripe Dashboard** (Express login link, tab mới) · Xuất CSV · Ngắt kết nối (bị chặn khi còn sự kiện đang bán hoặc chưa diễn) |
| Bị hạn chế | `restricted` | Stripe tắt `charges_enabled`, sự kiện đang bán chuyển sang Tạm dừng bán | **Cập nhật trên Stripe** → modal → trang Stripe |

Thanh 4 bước luôn hiện ở đầu màn: Tạo tài khoản Stripe → Hồ sơ trên Stripe → Stripe xác minh → Nhận thanh toán & rút tiền.

## 6. Dữ liệu trong prototype

Tên sự kiện, địa điểm, người dùng, số liệu doanh thu… là **dữ liệu mẫu** để hình dung bố cục — không phải yêu cầu nghiệp vụ. Quy tắc nghiệp vụ thật nằm trong [overview.md §3](../overview.md#3-quy-tắc-nghiệp-vụ).

## 7. File mẫu import

Hàng đầu là tên cột (đúng như bảng dưới); cột "Bắt buộc" kiểm tra ở bước dry-run. File mẫu có sẵn 2 dòng ví dụ và sheet "Hướng dẫn" liệt kê giá trị hợp lệ.

| Màn | File mẫu | Cột | Khoá khi trùng |
|---|---|---|---|
| Đơn vị hành chính | `mau-don-vi-hanh-chinh.xlsx` | `ma`*, `ten`*, `loai`* (Tỉnh · Thành phố · Phường · Xã · Đặc khu), `ma_cha` (bắt buộc với cấp xã), `hieu_luc_tu` | `ma` |
| Địa điểm | `mau-dia-diem.xlsx` | `ma`, `ten`*, `dia_chi`*, `ma_xa`* (mã cấp xã trong danh mục), `suc_chua`* | `ma` |
| Sơ đồ ghế | `mau-so-do-ghe.xlsx` | `ma_khu`*, `ten_khu`*, `hang`*, `ghe_tu`*, `ghe_den`*, `x`, `y` | `ma_khu` + `hang` + số ghế |

Lỗi thường gặp đã vẽ trong prototype: mã cha không tồn tại, loại không hợp lệ, trùng mã trong file, thiếu trường bắt buộc, `ghe_den` < `ghe_tu`, trùng ghế với dòng khác.

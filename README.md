# ETS2 Passenger Bus Addons (1.59)

Hai addon cho Euro Truck Simulator 2 phiên bản 1.59:

- HUD GPS + tốc độ chiếu trên kính lái cho các xe khách được hỗ trợ.
- Sửa hiện tượng xe khách tự va chạm với rơ-móc hành khách vô hình.

## Tải mod

Các file cài trực tiếp nằm trong [`releases/`](releases/):

- `PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs`
- `PASSENGER_TRAILER_COLLISION_FIX_1.59.scs`

Chép file `.scs` vào `Documents/Euro Truck Simulator 2/mod`, bật trong Mod Manager và đặt ưu tiên cao hơn mod xe khách.

Sau khi bật HUD, vào xưởng sửa xe và chọn phụ kiện ở vị trí kính lái `set_lglass`. Sau khi bật bản sửa rơ-móc, hãy nhận một chuyến hành khách mới.

## Xe hỗ trợ

- Kia Grandbird (`granbird.23`)
- Kim Long 99 (`kimlong.99`)
- Thaco Mobihome 2015–2016 (`man.tgx.sample`)
- Thaco Mobihome 2024 (`thaco.mbh.23`)
- Thaco Mobihome 2025 (`thaco.mbh.25`)

Phần sửa rơ-móc hỗ trợ hai family `passenger` và `crsthn.t_passag`. Kim Long chỉ được sửa nếu bản mod xe sử dụng một trong hai family này.

## Cấu trúc repo

- `releases/`: hai file `.scs` thành phẩm.
- `src/passenger_bus_hud/`: nội dung đóng gói của addon HUD.
- `src/passenger_trailer_fix/`: nội dung đóng gói của addon sửa rơ-móc.
- `src/hud_model_sources/`: các model PIM/PIT đã chỉnh cho ba nhóm cabin.
- `tools/`: công cụ PowerShell dùng để dịch chuyển model HUD.
- `tests/`: bộ kiểm tra cấu trúc package, model và phạm vi override.
- `docs/`: thiết kế và kế hoạch triển khai.

## Kiểm tra

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_bus_hud.ps1 -Path releases\PASSENGER_BUS_HUD_GPS_SPEED_1.59.scs

powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests\validate_passenger_trailer_fix.ps1 -Path releases\PASSENGER_TRAILER_COLLISION_FIX_1.59.scs -BaselineRoot <thu-muc-mod-xe-da-giai-nen>
```

## Ghi chú nguồn

HUD được phát triển dựa trên cấu trúc của dự án [ETS2 Optical HUD](https://github.com/mike-koch/ets2-optical-hud). Repo này không chứa mod xe thương mại, archive xe bị khóa, hoặc SCS Conversion Tools.

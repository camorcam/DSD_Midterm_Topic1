# T1 — APB GPIO: Kế hoạch triển khai 7 phase

> **Đối tượng:** Nhóm 2 sinh viên mới học Verilog/FSM.  
> **Mục tiêu:** Hoàn thành Topic 1 — APB GPIO and Register Bank with Interrupts trong **6 implementation phases + 1 buffer phase**.  
> **Cường độ:** Khoảng 8–10 giờ/người/phase.  
> **Phạm vi:** Đầy đủ yêu cầu bắt buộc; **không làm Stretch** (programmable debounce) trừ khi còn thời gian.  
> **FPGA target:** Intel Cyclone V SoC FPGA với Intel Quartus Prime, `.qsf` pin assignments, `.sdc` timing constraints và SignalTap.  
> **Board:** Terasic DE10-Standard, Cyclone V SoC `5CSXFC6D6F31C6N`, clock 50 MHz; device và pinout đã được xác nhận từ user manual. Board revision, Quartus version và khả năng nạp FPGA vẫn cần xác nhận.

## 1. Kế hoạch theo phase

| Phase | Trọng tâm | Mục tiêu / đầu ra |
|---|---|---|
| **1** | Kiến trúc + proposal | Chốt APB interface, register map, block diagram, FSM/timing diagrams; D1 bản đầu |
| **2** | RTL cơ bản | APB slave, registers, GPIO, synchronizer, interrupt; unit tests và tích hợp sơ bộ |
| **3** | Directed tests | Toàn bộ chức năng *Must have* chạy PASS trong simulation |
| **4** | Verification nâng cao | BFM, scoreboard, random tests, assertions, coverage |
| **5** | FPGA implementation | Demo trên board, timing/utilization reports |
| **6** | SignalTap + report + slides | Đủ bộ D1–D6, báo cáo và presentation |
| **7** | Dự phòng + rehearsal | Regression, sửa lỗi, luyện demo và Q&A |

### Phase 1 — Thiết kế kiến trúc + Proposal

**Mục tiêu:** Chốt specification và giao diện module trước khi viết code.

- **APB và register map:** Đọc APB4; phân tích các tín hiệu PSEL, PENABLE, PREADY, PSTRB, PSLVERR; vẽ APB FSM và timing read/write; chốt APB interface cùng register map.
- **GPIO và interrupt:** Thiết kế kiến trúc GPIO input/output 32-bit, 2-FF synchronizer, edge detection, interrupt status/clear; vẽ block diagram và đề xuất FPGA demo.
- **Kiến trúc và tài liệu:** Thống nhất module ports, reset values, register offsets, cách xử lý set/clear interrupt đồng thời; bắt đầu D1 (3–5 trang); xác nhận exact Cyclone V device part, board revision, Quartus version và pinout.
- **Đầu ra:** D1 bản đầu, block diagram, register map, interface list, FSM và timing diagrams.

### Phase 2 — Code RTL cơ bản

**Mục tiêu:** GPIO đọc/ghi được qua APB trong simulation.

- **APB và register bank:** Viết `apb_slave_ctrl.v`, `gpio_registers.v`; address decoder; xử lý PSTRB và PSLVERR; test read/write/reset.
- **GPIO và interrupt:** Viết `gpio_input_sync.v`, `gpio_interrupt.v`; direction và output logic; rising/falling/both-edge detection; INT_STATUS write-1-to-clear; unit tests.
- **Core integration:** Tích hợp `apb_gpio_top.v`, xử lý compile warnings và kiểm tra reset.
- **Đầu ra:** RTL cơ bản hoạt động; unit tests PASS; core đã tích hợp.

### Phase 3 — Integration + Directed Tests

**Mục tiêu:** Toàn bộ *Must have* hoạt động và vượt qua directed tests.

- **APB directed verification:** Viết APB BFM (`apb_read`, `apb_write`); test register read/write, default/reset values, byte strobes PSTRB, invalid address/PSLVERR, back-to-back transactions.
- **GPIO/interrupt directed verification:** Test rising/falling/both-edge interrupts theo từng pin, INT_ENABLE, W1C, input synchronizer và tình huống set/clear cùng lúc.
- **RTL stabilization:** Fix RTL và khóa các interface đã thống nhất.
- **Đầu ra:** Core RTL hoàn chỉnh; directed tests PASS. Đây là **mốc quyết định**: nếu còn lỗi chức năng bắt buộc thì ưu tiên sửa trước khi mở rộng.

### Phase 4 — Verification nâng cao

**Mục tiêu:** Testbench tự đánh giá PASS/FAIL và bao phủ các tình huống quan trọng.

- **APB/register verification:** Scoreboard/reference model cho registers; random APB reads/writes/addresses/PSTRB; protocol assertions (SETUP/ACCESS, stability, response timing).
- **GPIO/interrupt verification:** Random GPIO input edges và interrupt events; corner cases; kiểm tra không mất sự kiện theo chính sách đã thiết kế; coverage table.
- **Regression:** Chạy toàn bộ test suite, lưu waveforms, test logs và coverage summary.
- **Đầu ra:** BFM, scoreboard, random tests, assertions và coverage hoạt động, có bằng chứng PASS/FAIL.

### Phase 5 — FPGA Implementation

**Mục tiêu:** Chạy và demo được trên FPGA board.

- **Demo control:** Viết `apb_master_demo.v` (FSM master đơn giản), nối `fpga_top.v` và tạo chuỗi APB transactions demo.
- **Board implementation:** Tạo `.qsf` pin assignments và `.sdc` timing constraints; clock/reset, button debounce, LED/switch/IRQ LED mapping; Quartus synthesis, implementation và nạp `.sof`.
- **FPGA validation:** Demo DATA_OUT, DATA_IN, interrupt set/clear; xem utilization/timing reports và sửa timing violations nếu có.
- **Đầu ra:** FPGA demo chạy được; Quartus project, `.qsf`, `.sdc`, `.sof`, utilization/timing reports.
- **Trạng thái:** Phase 5A và phần chuẩn bị offline của Phase 5B (DE10-Standard wrapper, QSF/SDC, board-level simulation) đã hoàn tất; còn chờ chạy Quartus và kiểm tra phần cứng.

### Phase 6 — SignalTap, Báo cáo, Slides

**Mục tiêu:** Hoàn thiện toàn bộ sản phẩm nộp.

- **Verification evidence:** Regression lần cuối, capture APB transaction bằng SignalTap; viết phần protocol, RTL và verification của báo cáo.
- **FPGA evidence:** Chốt demo và bằng chứng FPGA; viết phần implementation, timing, problems/fixes; chuẩn bị slides.
- **Deliverable integration:** Kiểm tra README, source tree, test logs, screenshots/waveforms; hoàn thiện D1–D6.
- **Đầu ra:** Báo cáo kỹ thuật 12–20 trang, slide 15–20 trang, FPGA evidence và package có thể nộp.

### Phase 7 — Dự phòng + Tổng duyệt

**Mục tiêu:** Ổn định sản phẩm và tránh lỗi lúc demo.

- **Simulation readiness:** Chạy final regression; kiểm tra đầy đủ source/docs; luyện giải thích APB, FSM, PSTRB, PSLVERR.
- **FPGA readiness:** Chạy lại demo trên Cyclone V SoC FPGA; xác minh timing, reset, pin mapping và SignalTap capture; luyện giải thích GPIO, interrupt, synchronizer.
- **Presentation readiness:** Tập trình bày/demo trong 15 phút, dự kiến 5 phút Q&A; fix lỗi còn sót.
- **Đầu ra:** Project sẵn sàng trình bày và nộp.

## 2. Ước lượng giờ công

| Hạng mục | Giờ công cả nhóm (ước lượng) |
|---|---:|
| Thiết kế và D1 | 14 |
| RTL và integration | 24 |
| Verification | 30 |
| FPGA | 20 |
| Báo cáo và slides | 18 |
| Dự phòng | 14 |
| **Tổng** | **120** |

Khoảng **60 giờ/người** nếu chia đều. Đây là ước lượng để lập kế hoạch, không phải số giờ do đề quy định.

## 3. Các mốc bắt buộc

- [ ] **End of Phase 1:** Register map, FSM, timing diagrams, module interfaces đã chốt.
- [x] **End of Phase 2:** APB GPIO đọc/ghi register được trong simulation; core đã tích hợp và unit tests PASS.
- [x] **End of Phase 3:** Toàn bộ tính năng Must have PASS directed tests.
- [x] **End of Phase 4:** BFM, scoreboard, random tests, assertions và coverage hoàn chỉnh.
- [ ] **End of Phase 5:** FPGA demo chạy được, đạt timing; có utilization/timing reports.
- [ ] **End of Phase 6:** Đầy đủ D1–D6, gồm SignalTap capture.
- [ ] **Phase 7:** Final regression và rehearsal hoàn tất.

## 4. Những yêu cầu không được cắt

- APB4 slave và giao thức chuẩn (bao gồm PREADY, PSLVERR, PSTRB, PPROT).
- GPIO 32-bit, register map rõ ràng.
- Năm register: DATA_OUT, DATA_IN, DIRECTION, INT_ENABLE, INT_STATUS (W1C).
- Rising/falling/both-edge interrupts theo từng pin.
- 2-FF input synchronizers; đồng bộ input bất đồng bộ và debounce buttons khi demo FPGA.
- Error response khi địa chỉ không được map; byte writes bằng PSTRB.
- Unit tests, BFM, self-checking reference model/scoreboard, directed/random tests, assertions, coverage.
- Cyclone V SoC FPGA demo, Quartus project, `.sof`, `.qsf`/`.sdc`, timing/utilization reports và SignalTap capture.
- D1–D6 và phần trình bày/hỏi đáp cá nhân.

**Có thể bỏ để tiết kiệm thời gian:** programmable debounce (*Stretch*), UART-to-APB debug bridge (thay bằng FSM master nhỏ), chức năng hiển thị phụ không bắt buộc.

> **Chú ý:** Chỉ nối một phần GPIO ra LEDs/switches của board không có nghĩa giảm IP xuống 8-bit; lõi vẫn phải hỗ trợ 32-bit.

## 5. Rủi ro & cách đối phó

| Rủi ro | Cách xử lý |
|---|---|
| Chưa quen APB timing | Vẽ read/write timing và viết APB BFM từ sớm. |
| PSTRB hoặc W1C sai | Test byte masks và clear từng bit; có scoreboard. |
| Interrupt sai khi edge trùng clear | Chốt chính sách ưu tiên trước khi code, thêm directed test. |
| Quartus setup hoặc programming connection chưa sẵn sàng | Device và pinout DE10-Standard đã xác nhận; tiếp tục xác nhận board revision, Quartus version và programming connection. |
| Simulation PASS nhưng FPGA lỗi | Synthesis sớm, kiểm tra constraints/reset/timing. |
| Chậm tiến độ | Ưu tiên RTL + directed PASS trước; bỏ Stretch, không bỏ verification bắt buộc. |
| Không đủ thời gian viết tài liệu | Ghi lại thiết kế, test logs và ảnh chụp bằng chứng sau mỗi phase. |

## 6. Deliverables phải nộp

| Mã | Nội dung |
|---|---|
| **D1** | Proposal 3–5 trang: topic, block diagram, signal list, register map, FSM, test plan, FPGA demo plan. |
| **D2** | RTL source, parameters, README và cấu trúc file. |
| **D3** | Testbench, BFM, assertions, PASS/FAIL logs, coverage, waveforms. |
| **D4** | Quartus project, `.qsf`/`.sdc`, `.sof`, utilization và timing reports, SignalTap capture. |
| **D5** | Technical report 12–20 trang. |
| **D6** | 15–20 slides; 15 phút trình bày/demo và 5 phút hỏi đáp. |

## 7. Kết luận

Kế hoạch gồm **6 implementation phases + 1 buffer phase**. Với nhóm mới học Verilog/FSM, ưu tiên số một là đến cuối **Phase 3** phải đạt **directed tests PASS** cho toàn bộ tính năng bắt buộc. Phase 4 hoàn thiện verification, Phase 5 demo FPGA, Phase 6 đóng gói tài liệu. Phase 7 dùng để sửa lỗi phát sinh, chạy lại regression và tổng duyệt.

*Lưu ý: lịch checkpoint chính thức do giảng viên công bố trên Blackboard; kế hoạch 7 phase này là workflow riêng của nhóm, không thay cho lịch môn học.*

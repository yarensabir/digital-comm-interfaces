`timescale 1ns / 1ps

module apb_uart_slave_tb;

    // Parametreler (Hızlı simülasyon için küçük saat böleni)
    localparam CLK_FREQ  = 10_000_000; // 10 MHz
    localparam BAUD_RATE = 1_000_000;  // 1 MBaud (Hızlı simülasyon)

    // Sinyal Tanımları
    reg         PCLK;
    reg         PRESETn;
    reg  [31:0] PADDR;
    reg         PSEL;
    reg         PENABLE;
    reg         PWRITE;
    reg  [31:0] PWDATA;
    wire [31:0] PRDATA;
    wire        PREADY;
    wire        PSLVERR;

    wire        tx_pin;
    wire        rx_pin;

    // Loopback Bağlantısı: TX pinini doğrudan RX pinine veriyoruz
    assign rx_pin = tx_pin;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    // Hızlı simülasyon için bit başına 10 clock
    localparam CLKS_PER_BIT = 10;

    apb_uart_slave #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) dut (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR),
        .tx_pin(tx_pin),
        .rx_pin(rx_pin)
    );

    // Saat Üretimi (10 MHz -> 100 ns periyot)
    always #50 PCLK = ~PCLK;

    // -------------------------------------------------------------------------
    // APB Bus Driver Görevleri (Tasks)
    // -------------------------------------------------------------------------
    // Bir APB Yazma Transferi (2 Saat Çevrimi)
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWDATA  <= data;
            PWRITE  <= 1'b1;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0; // Setup fazı

            @(posedge PCLK);
            PENABLE <= 1'b1; // Access fazı

            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
        end
    endtask

    // Bir APB Okuma Transferi (2 Saat Çevrimi)
    task apb_read(input [31:0] addr, output [31:0] read_data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0; // Setup fazı

            @(posedge PCLK);
            PENABLE <= 1'b1; // Access fazı

            @(posedge PCLK);
            read_data = PRDATA;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Simülasyon Akışı
    // -------------------------------------------------------------------------
    reg [31:0] rdata;

    initial begin
        // Başlangıç Değerleri
        PCLK    = 0;
        PRESETn = 0;
        PADDR   = 0;
        PWDATA  = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;

        // Reset süreci
        #200;
        PRESETn = 1;
        #100;

        $display("\n========================================================");
        $display("[TB] APB-UART Slave Entegrasyon Testi Baslatildi");
        $display("========================================================");

        // 1. Veri Yazma: TX_DATA_REG (0x08) adresine 0x55 yaz
        $display("[TB] 1. TX_DATA_REG (0x08) adresine 0x55 yaziliyor...");
        apb_write(32'h0000_0008, 32'h0000_0055);

        // 2. Tetikleme: CTRL_REG (0x00) adresine tx_start (Bit 0) = 1 yaz
        $display("[TB] 2. CTRL_REG (0x00) uzerinden TX tetikleniyor...");
        apb_write(32'h0000_0000, 32'h0000_0001);

        // 3. Durum Kontrolü: tx_busy durumunu kontrol et
        #200;
        apb_read(32'h0000_0004, rdata);
        $display("[TB] 3. STATUS_REG okundu: 0x%08X (tx_busy = %b)", rdata, rdata[0]);

        // 4. Paketin RX tarafından tamamen alınmasını bekle (Polling)
        $display("[TB] 4. RX tarafindan verinin tamamlanmasi bekleniyor...");
        rdata = 0;
        while (rdata[1] == 1'b0) begin // Bit 1: rx_done
            apb_read(32'h0000_0004, rdata);
            #100;
        end
        $display("[TB] RX Islemi Tamamlandi! STATUS_REG: 0x%08X", rdata);

        // 5. Veri Okuma: RX_DATA_REG (0x0C) adresini oku
        apb_read(32'h0000_000C, rdata);
        $display("[TB] 5. RX_DATA_REG (0x0C) okunan veri: 0x%02X", rdata[7:0]);

        // Otomatik Doğrulama Kontrolü
        if (rdata[7:0] === 8'h55) begin
            $display("\n[BASARILI] APB Veriyolu ve UART loopback iletisimi dogrulandi!\n");
        end else begin
            $display("\n[HATA] Beklenen: 0x55, Okunan: 0x%02X\n", rdata[7:0]);
        end

        #500;
        $finish;
    end

endmodule
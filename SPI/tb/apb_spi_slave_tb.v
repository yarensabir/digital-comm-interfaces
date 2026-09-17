`timescale 1ns / 1ps

module apb_spi_slave_tb;

    // Simülasyon için hızlı saat bölücü
    localparam CLK_DIV = 4;

    // APB3 Sinyalleri
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

    // SPI Hatları
    wire        sck;
    wire        mosi;
    wire        miso;
    wire        cs;

    // Loopback Bağlantısı: MOSI'den çıkanı MISO'ya geri besle
    assign miso = mosi;

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    apb_spi_slave #(
        .CLK_DIV(CLK_DIV)
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
        .sck(sck),
        .mosi(mosi),
        .miso(miso),
        .cs(cs)
    );

    // 100 MHz Saat Üretimi (10 ns periyot)
    always #5 PCLK = ~PCLK;

    // -------------------------------------------------------------------------
    // APB Bus Tasks
    // -------------------------------------------------------------------------
    task apb_write(input [31:0] addr, input [31:0] data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWDATA  <= data;
            PWRITE  <= 1'b1;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            @(posedge PCLK);
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
            PWRITE  <= 1'b0;
        end
    endtask

    task apb_read(input [31:0] addr, output [31:0] read_data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;

            @(posedge PCLK);
            PENABLE <= 1'b1;

            @(posedge PCLK);
            read_data = PRDATA;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Test Senaryosu
    // -------------------------------------------------------------------------
    reg [31:0] rdata;

    initial begin
        PCLK    = 0;
        PRESETn = 0;
        PADDR   = 0;
        PWDATA  = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;

        #40;
        PRESETn = 1;
        #20;

        $display("\n========================================================");
        $display("[TB] APB-SPI Slave Entegrasyon Testi Baslatildi");
        $display("========================================================");

        // 1. Veri Yazma: TX_DATA_REG (0x08) adresine 0xA5 yaz
        $display("[TB] 1. TX_DATA_REG (0x08) adresine 0xA5 yaziliyor...");
        apb_write(32'h0000_0008, 32'h0000_00A5);

        // 2. Tetikleme: CTRL_REG (0x00) üzerinden start bitini 1 yap
        $display("[TB] 2. CTRL_REG (0x00) uzerinden SPI transferi baslatiliyor...");
        apb_write(32'h0000_0000, 32'h0000_0001);

        // 3. Aktarımın tamamlanmasını bekle (busy bayrağının 0'a düşmesini bekle)
        $display("[TB] 3. SPI transferi bekleniyor (polling)...");
        #30;
        rdata = 32'h0000_0001;
        while (rdata[0] == 1'b1) begin // Bit 0: busy
            apb_read(32'h0000_0004, rdata);
            #10;
        end
        $display("[TB] Transfer bitti! STATUS_REG: 0x%08X", rdata);

        // 4. Veri Okuma: RX_DATA_REG (0x0C) adresini oku
        apb_read(32'h0000_000C, rdata);
        $display("[TB] 4. RX_DATA_REG (0x0C) okunan veri: 0x%02X", rdata[7:0]);

        // Doğrulama
        if (rdata[7:0] === 8'hA5) begin
            $display("\n[BASARILI] APB Slave SPI loopback iletisimi dogrulandi!\n");
        end else begin
            $display("\n[HATA] Beklenen: 0xA5, Okunan: 0x%02X\n", rdata[7:0]);
        end

        #100;
        $finish;
    end

endmodule
`timescale 1ns / 1ps

module apb_i2c_slave_tb;

    // Hızlı simülasyon için düşük saat bölücü
    localparam CLK_DIV = 10;

    // APB3 Veriyolu Sinyalleri
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

    // I2C Hatları
    wire scl;
    wire sda;

    // I2C Open-drain için Pull-up dirençleri
    pullup(scl);
    pullup(sda);

    // -------------------------------------------------------------------------
    // Device Under Test (DUT)
    // -------------------------------------------------------------------------
    apb_i2c_slave #(
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
        .scl(scl),
        .sda(sda)
    );

    // 100 MHz Sistem Saati (10 ns periyot)
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
    // Basit I2C Slave Modeli (ACK Üretici)
    // -------------------------------------------------------------------------
    reg sda_slave_drive;
    assign sda = (sda_slave_drive) ? 1'b0 : 1'bz;

    integer bit_idx;
    initial begin
        sda_slave_drive = 0;
        forever begin
            // START koşulunu bekle (SCL=1 iken SDA düşer)
            @(negedge sda);
            if (scl == 1'b1) begin
                // Adres + R/W (8 bit) için SCL yükselen kenarlarını say
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    @(posedge scl);
                end
                
                // 9. çevrim: Slave Adres ACK bas (SDA = 0)
                @(negedge scl);
                sda_slave_drive = 1;
                @(negedge scl);
                sda_slave_drive = 0;

                // Veri (8 bit) için SCL yükselen kenarlarını say
                for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                    @(posedge scl);
                end

                // 9. çevrim: Veri ACK bas (SDA = 0)
                @(negedge scl);
                sda_slave_drive = 1;
                @(negedge scl);
                sda_slave_drive = 0;
            end
        end
    end

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
        #40;

        $display("\n========================================================");
        $display("[TB] APB-I2C Slave Entegrasyon Testi Baslatildi");
        $display("========================================================");

        // 1. Veri Hazırlama: TX_DATA_REG (0x08) adresine 0x3C yaz
        $display("[TB] 1. TX_DATA_REG (0x08) adresine 0x3C yaziliyor...");
        apb_write(32'h0000_0008, 32'h0000_003C);

        // 2. Transferi Başlatma: CTRL_REG (0x00)
        // slave_addr = 7'h50 (0101000b) -> Bits [8:2] = 7'h50 (Kaydırma: 0x50 << 2 = 0x140)
        // rw = 0 (Yazma)               -> Bit 1 = 0
        // start = 1                    -> Bit 0 = 1
        // PWDATA = 0x0000_0141
        $display("[TB] 2. CTRL_REG (0x00) uzerinden I2C Yazma transferi baslatiliyor (Addr: 0x50)...");
        apb_write(32'h0000_0000, 32'h0000_0141);

        // 3. Polling: Transferin bitmesini bekle (STATUS_REG busy bitini izle)
        $display("[TB] 3. I2C transferi bekleniyor (polling)...");
        #100;
        rdata = 32'h0000_0001;
        while (rdata[0] == 1'b1) begin // Bit 0: busy
            apb_read(32'h0000_0004, rdata);
            #40;
        end
        $display("[TB] Transfer bitti! STATUS_REG: 0x%08X", rdata);

        // 4. Hata Kontrolü: Bit 2 ack_error olmamalı
        if (rdata[2] == 1'b0) begin
            $display("\n[BASARILI] APB uzerinden I2C transferi ACK alinarak tamamlandi!\n");
        end else begin
            $display("\n[HATA] I2C transferinde NACK (ack_error) tespit edildi!\n");
        end

        #200;
        $finish;
    end

endmodule
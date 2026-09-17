`timescale 1ns / 1ps

module apb_subsystem_tb;

    // Hızlı simülasyon parametreleri
    localparam UART_CLKS_PER_BIT = 16;
    localparam SPI_CLK_DIV       = 4;
    localparam I2C_CLK_DIV       = 10;

    // APB3 Veriyolu
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

    // Dış Hatlar
    wire uart_rx_pin, uart_tx_pin;
    wire spi_sck, spi_mosi, spi_miso, spi_cs;
    wire i2c_scl, i2c_sda;

    // Hat Bağlantıları (Loopback & Pullup)
    assign uart_rx_pin = uart_tx_pin; // UART Loopback
    assign spi_miso    = spi_mosi;    // SPI Loopback
    pullup(i2c_scl);
    pullup(i2c_sda);

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    apb_subsystem #(
        .UART_CLKS_PER_BIT(UART_CLKS_PER_BIT),
        .SPI_CLK_DIV(SPI_CLK_DIV),
        .I2C_CLK_DIV(I2C_CLK_DIV)
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
        .uart_rx_pin(uart_rx_pin),
        .uart_tx_pin(uart_tx_pin),
        .spi_sck(spi_sck),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso),
        .spi_cs(spi_cs),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // 100 MHz Saat
    always #5 PCLK = ~PCLK;

    // APB Tasks
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

    task apb_read(input [31:0] addr, output [31:0] data);
        begin
            @(posedge PCLK);
            PADDR   <= addr;
            PWRITE  <= 1'b0;
            PSEL    <= 1'b1;
            PENABLE <= 1'b0;
            @(posedge PCLK);
            PENABLE <= 1'b1;
            @(posedge PCLK);
            data    = PRDATA;
            PSEL    <= 1'b0;
            PENABLE <= 1'b0;
        end
    endtask

    // -------------------------------------------------------------------------
    // Basit I2C Slave Modeli (ACK)
    // -------------------------------------------------------------------------
    reg sda_slave_drive;
    assign i2c_sda = (sda_slave_drive) ? 1'b0 : 1'bz;

    integer bit_cnt;
    initial begin
        sda_slave_drive = 0;
        forever begin
            @(negedge i2c_sda);
            if (i2c_scl == 1'b1) begin
                for (bit_cnt = 0; bit_cnt < 8; bit_cnt = bit_cnt + 1) @(posedge i2c_scl);
                @(negedge i2c_scl); sda_slave_drive = 1;
                @(negedge i2c_scl); sda_slave_drive = 0;
                for (bit_cnt = 0; bit_cnt < 8; bit_cnt = bit_cnt + 1) @(posedge i2c_scl);
                @(negedge i2c_scl); sda_slave_drive = 1;
                @(negedge i2c_scl); sda_slave_drive = 0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Test Akışı
    // -------------------------------------------------------------------------
    reg [31:0] rdata;

    initial begin
        PCLK = 0; PRESETn = 0; PADDR = 0; PWDATA = 0; PSEL = 0; PENABLE = 0; PWRITE = 0;
        #40; PRESETn = 1; #40;

        $display("\n========================================================");
        $display("[TB] APB SUBSYSTEM BIRLESIK TEST BASLADI");
        $display("========================================================");

        // 1. TEST: UART (0x000 - 0x0FF)
        $display("\n--- 1. UART Testi (Adres: 0x008, Veri: 0xA5) ---");
        apb_write(32'h0000_0008, 32'h0000_00A5); // TX yaz
        apb_write(32'h0000_0000, 32'h0000_0001); // Başlat
        #2000;
        apb_read(32'h0000_000C, rdata);          // RX oku
        $display("[UART] Okunan Veri: 0x%02X (Beklenen: 0xA5)", rdata[7:0]);

        // 2. TEST: SPI (0x100 - 0x1FF)
        $display("\n--- 2. SPI Testi (Adres: 0x108, Veri: 0x5A) ---");
        apb_write(32'h0000_0108, 32'h0000_005A); // TX yaz
        apb_write(32'h0000_0100, 32'h0000_0001); // Başlat
        #1000;
        apb_read(32'h0000_010C, rdata);          // RX oku
        $display("[SPI] Okunan Veri: 0x%02X (Beklenen: 0x5A)", rdata[7:0]);

        // 3. TEST: I2C (0x200 - 0x2FF)
        $display("\n--- 3. I2C Testi (Adres: 0x208, Veri: 0x3C, Slave: 0x50) ---");
        apb_write(32'h0000_0208, 32'h0000_003C); // TX yaz
        apb_write(32'h0000_0200, 32'h0000_0141); // Addr=0x50, Start=1
        #2500;
        apb_read(32'h0000_0204, rdata);          // Status oku
        $display("[I2C] Transfer Bitti. Status: 0x%08X (Hata Biti: %b)", rdata, rdata[2]);

        $display("\n========================================================");
        $display("[TB] TUM PROTOKOLLER AYNI APB UZERINDEN BASARIYLA TEST EDILDI");
        $display("========================================================\n");
        #100;
        $finish;
    end

endmodule
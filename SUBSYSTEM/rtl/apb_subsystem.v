`timescale 1ns / 1ps

module apb_subsystem #(
    parameter UART_CLKS_PER_BIT = 868, // 100 MHz @ 115200 Baud
    parameter SPI_CLK_DIV       = 10,  // SPI Saat Bölücü
    parameter I2C_CLK_DIV       = 250  // I2C Saat Bölücü
)(
    // -------------------------------------------------------------------------
    // Ortak APB3 Slave Arayüzü (Ana İşlemci / Master Bağlantısı)
    // -------------------------------------------------------------------------
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output reg         PREADY,
    output reg         PSLVERR,

    // -------------------------------------------------------------------------
    // Fiziksel Dış Hatlar
    // -------------------------------------------------------------------------
    // UART Hatları
    input  wire        uart_rx_pin,
    output wire        uart_tx_pin,

    // SPI Hatları
    output wire        spi_sck,
    output wire        spi_mosi,
    input  wire        spi_miso,
    output wire        spi_cs,

    // I2C Hatları
    output wire        i2c_scl,
    inout  wire        i2c_sda
);

    // -------------------------------------------------------------------------
    // Adres Çözümleme Mantığı (Address Decoding)
    // -------------------------------------------------------------------------
    // PADDR[11:8] tabanlı ayrım:
    // 4'h0 -> 0x000 - 0x0FF : UART
    // 4'h1 -> 0x100 - 0x1FF : SPI
    // 4'h2 -> 0x200 - 0x2FF : I2C
    
    wire psel_uart = PSEL && (PADDR[11:8] == 4'h0);
    wire psel_spi  = PSEL && (PADDR[11:8] == 4'h1);
    wire psel_i2c  = PSEL && (PADDR[11:8] == 4'h2);

    // Çevre Birimi APB Yanıt Telleri
    wire [31:0] prdata_uart, prdata_spi, prdata_i2c;
    wire        pready_uart, pready_spi, pready_i2c;
    wire        pslverr_uart, pslverr_spi, pslverr_i2c;

    // -------------------------------------------------------------------------
    // Master Geri Dönüş Çoklayıcısı (Read Data & Ready Muxing)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (PADDR[11:8])
            4'h0: begin
                PRDATA  = prdata_uart;
                PREADY  = pready_uart;
                PSLVERR = pslverr_uart;
            end
            4'h1: begin
                PRDATA  = prdata_spi;
                PREADY  = pready_spi;
                PSLVERR = pslverr_spi;
            end
            4'h2: begin
                PRDATA  = prdata_i2c;
                PREADY  = pready_i2c;
                PSLVERR = pslverr_i2c;
            end
            default: begin
                PRDATA  = 32'h0000_0000;
                PREADY  = 1'b1;
                PSLVERR = PSEL; // Haritalanmamış adrese erişimde hata üret
            end
        endcase
    end

    // -------------------------------------------------------------------------
    // 1. UART APB Slave Örneği
    // -------------------------------------------------------------------------
    apb_uart_slave #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) u_uart (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(psel_uart),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(prdata_uart),
        .PREADY(pready_uart),
        .PSLVERR(pslverr_uart),
        .rx_pin(uart_rx_pin),
        .tx_pin(uart_tx_pin)
    );

    // -------------------------------------------------------------------------
    // 2. SPI APB Slave Örneği
    // -------------------------------------------------------------------------
    apb_spi_slave #(
        .CLK_DIV(SPI_CLK_DIV)
    ) u_spi (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(psel_spi),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(prdata_spi),
        .PREADY(pready_spi),
        .PSLVERR(pslverr_spi),
        .sck(spi_sck),
        .mosi(spi_mosi),
        .miso(spi_miso),
        .cs(spi_cs)
    );

    // -------------------------------------------------------------------------
    // 3. I2C APB Slave Örneği
    // -------------------------------------------------------------------------
    apb_i2c_slave #(
        .CLK_DIV(I2C_CLK_DIV)
    ) u_i2c (
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PADDR(PADDR),
        .PSEL(psel_i2c),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PWDATA(PWDATA),
        .PRDATA(prdata_i2c),
        .PREADY(pready_i2c),
        .PSLVERR(pslverr_i2c),
        .scl(i2c_scl),
        .sda(i2c_sda)
    );

endmodule
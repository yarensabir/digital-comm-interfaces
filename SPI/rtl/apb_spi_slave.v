`timescale 1ns / 1ps

module apb_spi_slave #(
    parameter CLK_DIV = 4
)(
    // APB3 Veriyolu Arayüzü
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire [31:0] PADDR,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg  [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    // Harici SPI Arayüz Pinleri
    output wire        sck,
    output wire        mosi,
    input  wire        miso,
    output wire        cs
);

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // İç APB Yazmaçları
    reg [7:0] tx_data_reg;
    reg       start_reg;
    reg       busy_reg;

    // spi_master Bağlantı Telleri
    wire [7:0] rx_data_wire;
    wire       done_tick_wire;

    // APB Yazma Transfer Koşulu
    wire apb_write_transfer = PSEL && PENABLE && PWRITE;

    // -------------------------------------------------------------------------
    // 1. APB Register Yazma Mantığı (Master -> Slave)
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_data_reg <= 8'h00;
            start_reg   <= 1'b0;
            busy_reg    <= 1'b0;
        end else begin
            // start sinyali tek saat çevrimlik bir darbedir
            start_reg <= 1'b0;

            // Transfer bittiğinde busy bayrağını temizle
            if (done_tick_wire) begin
                busy_reg <= 1'b0;
            end

            if (apb_write_transfer) begin
                case (PADDR[3:0])
                    4'h0: begin // 0x00: CTRL_REG
                        start_reg <= PWDATA[0];
                        if (PWDATA[0]) begin
                            busy_reg <= 1'b1;
                        end
                    end
                    4'h8: begin // 0x08: TX_DATA_REG
                        tx_data_reg <= PWDATA[7:0];
                    end
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. APB Register Okuma Mantığı (Slave -> Master)
    // -------------------------------------------------------------------------
    always @(*) begin
        PRDATA = 32'h0000_0000;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:0])
                4'h0: PRDATA = {31'b0, start_reg};
                4'h4: PRDATA = {30'b0, done_tick_wire, busy_reg}; // Bit 1: done, Bit 0: busy
                4'h8: PRDATA = {24'b0, tx_data_reg};
                4'hC: PRDATA = {24'b0, rx_data_wire};
                default: PRDATA = 32'h0000_0000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 3. SPI Master Modül Bağlantısı
    // -------------------------------------------------------------------------
    spi_master #(
        .CLK_DIV(CLK_DIV)
    ) u_spi_master (
        .clk(PCLK),
        .rst_n(PRESETn),
        .start(start_reg),
        .tx_data(tx_data_reg),
        .miso(miso),
        .sck(sck),
        .mosi(mosi),
        .cs(cs),
        .rx_data(rx_data_wire),
        .done_tick(done_tick_wire)
    );

endmodule
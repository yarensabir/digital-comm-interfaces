`timescale 1ns / 1ps

module apb_uart_slave #(
    parameter CLKS_PER_BIT = 10400 // 100 MHz clock, 9600 Baud
)(
    // APB3 Veriyolu Sinyalleri
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

    // UART Hatları
    output wire        tx_pin,
    input  wire        rx_pin
);

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // İç Registerlar
    reg [7:0] tx_data_reg;
    reg       tx_start_reg;

    // Alt Modül Bağlantı Telleri
    wire [7:0] rx_data_wire;
    wire       rx_done_wire;

    // APB Yazma Tetikleyici
    wire apb_write_transfer = PSEL && PENABLE && PWRITE;

    // -------------------------------------------------------------------------
    // 1. APB Register Yazma (Master -> Slave)
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            tx_data_reg  <= 8'h00;
            tx_start_reg <= 1'b0;
        end else begin
            tx_start_reg <= 1'b0; // Otomatik temizlenen tek vuruşluk start

            if (apb_write_transfer) begin
                case (PADDR[3:0])
                    4'h0: tx_start_reg <= PWDATA[0]; // 0x00: CTRL_REG
                    4'h8: tx_data_reg  <= PWDATA[7:0]; // 0x08: TX_DATA_REG
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. APB Register Okuma (Slave -> Master)
    // -------------------------------------------------------------------------
    always @(*) begin
        PRDATA = 32'h0000_0000;
        if (PSEL && !PWRITE) begin
            case (PADDR[3:0])
                4'h0: PRDATA = {31'b0, tx_start_reg};
                4'h4: PRDATA = {30'b0, rx_done_wire, 1'b0}; // STATUS: [1]=rx_done
                4'h8: PRDATA = {24'b0, tx_data_reg};
                4'hC: PRDATA = {24'b0, rx_data_wire};
                default: PRDATA = 32'h0000_0000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 3. UART Modül Bağlantıları (Gerçek Port İsimlerine Göre)
    // -------------------------------------------------------------------------
    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_tx (
        .clk(PCLK),
        .rst_n(PRESETn),
        .tx_data(tx_data_reg),
        .tx_start(tx_start_reg),
        .tx_pin(tx_pin)
    );

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) u_rx (
        .clk(PCLK),
        .rst_n(PRESETn),
        .rx_pin(rx_pin),
        .rx_data(rx_data_wire),
        .rx_done(rx_done_wire)
    );

endmodule
`timescale 1ns / 1ps

module apb_i2c_slave #(
    parameter CLK_DIV = 250
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

    // Harici I2C Hatları
    output wire        scl,
    inout  wire        sda
);

    assign PREADY  = 1'b1;
    assign PSLVERR = 1'b0;

    // İç APB Yazmaçları
    reg       start_reg;
    reg       rw_reg;
    reg [6:0] slave_addr_reg;
    reg [7:0] tx_data_reg;
    reg       busy_reg;
    reg       ack_error_latch;

    // i2c_master_rw Bağlantı Telleri
    wire [7:0] rx_data_wire;
    wire       ack_error_wire;
    wire       done_tick_wire;

    // APB Yazma Transfer Koşulu
    wire apb_write_transfer = PSEL && PENABLE && PWRITE;

    // -------------------------------------------------------------------------
    // 1. APB Register Yazma Mantığı (Master -> Slave)
    // -------------------------------------------------------------------------
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            start_reg        <= 1'b0;
            rw_reg           <= 1'b0;
            slave_addr_reg   <= 7'h00;
            tx_data_reg      <= 8'h00;
            busy_reg         <= 1'b0;
            ack_error_latch  <= 1'b0;
        end else begin
            // start sinyali tek çevrimlik bir tetikleyicidir
            start_reg <= 1'b0;

            // Transfer bittiğinde durumları güncelle
            if (done_tick_wire) begin
                busy_reg        <= 1'b0;
                ack_error_latch <= ack_error_wire;
            end

            if (apb_write_transfer) begin
                case (PADDR[3:0])
                    4'h0: begin // 0x00: CTRL_REG
                        start_reg      <= PWDATA[0];
                        rw_reg         <= PWDATA[1];
                        slave_addr_reg <= PWDATA[8:2];
                        if (PWDATA[0]) begin
                            busy_reg        <= 1'b1;
                            ack_error_latch <= 1'b0;
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
                4'h0: PRDATA = {23'b0, slave_addr_reg, rw_reg, start_reg};
                4'h4: PRDATA = {29'b0, ack_error_latch, done_tick_wire, busy_reg}; // Bit 2: ack_error, Bit 1: done, Bit 0: busy
                4'h8: PRDATA = {24'b0, tx_data_reg};
                4'hC: PRDATA = {24'b0, rx_data_wire};
                default: PRDATA = 32'h0000_0000;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // 3. I2C Master Modül Bağlantısı
    // -------------------------------------------------------------------------
    i2c_master_rw #(
        .CLK_DIV(CLK_DIV)
    ) u_i2c_master (
        .clk(PCLK),
        .rst_n(PRESETn),
        .start(start_reg),
        .slave_addr(slave_addr_reg),
        .rw(rw_reg),
        .tx_data(tx_data_reg),
        .scl(scl),
        .sda(sda),
        .rx_data(rx_data_wire),
        .ack_error(ack_error_wire),
        .done_tick(done_tick_wire)
    );

endmodule
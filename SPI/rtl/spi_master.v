`timescale 1ns / 1ps

module spi_master #(
    parameter CLK_DIV = 4  // Simülasyon için 4
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,
    
    output reg        sck,
    output reg        mosi,
    output reg        cs,
    output reg  [7:0] rx_data,
    output reg        done_tick
);

    localparam STATE_IDLE     = 2'b00;
    localparam STATE_TRANSFER = 2'b01;
    localparam STATE_DONE     = 2'b10;

    reg [1:0] state;
    reg [7:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] tx_reg;
    reg [7:0] rx_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            sck       <= 1'b0;
            mosi      <= 1'b0;
            cs        <= 1'b1;
            rx_data   <= 8'd0;
            done_tick <= 1'b0;
            clk_cnt   <= 8'd0;
            bit_idx   <= 3'd7;
            tx_reg    <= 8'd0;
            rx_reg    <= 8'd0;
        end else begin
            done_tick <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    sck <= 1'b0;
                    cs  <= 1'b1;
                    if (start) begin
                        cs        <= 1'b0;
                        tx_reg    <= tx_data;
                        mosi      <= tx_data[7];
                        bit_idx   <= 3'd7;
                        clk_cnt   <= 8'd0;
                        state     <= STATE_TRANSFER;
                    end
                end

                STATE_TRANSFER: begin
                    if (clk_cnt == ((CLK_DIV / 2) - 1)) begin
                        sck     <= 1'b1;
                        rx_reg  <= {rx_reg[6:0], miso};
                        clk_cnt <= clk_cnt + 1'b1;
                    end 
                    else if (clk_cnt == (CLK_DIV - 1)) begin
                        sck     <= 1'b0;
                        clk_cnt <= 8'd0;
                        
                        if (bit_idx == 3'd0) begin
                            state <= STATE_DONE;
                        end else begin
                            bit_idx <= bit_idx - 1'b1;
                            mosi    <= tx_reg[bit_idx - 1'b1];
                        end
                    end 
                    else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                STATE_DONE: begin
                    cs        <= 1'b1;
                    mosi      <= 1'b0;
                    done_tick <= 1'b1;
                    rx_data   <= rx_reg;
                    state     <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
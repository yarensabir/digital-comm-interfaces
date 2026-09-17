`timescale 1ns / 1ps

module uart_rx #(
    parameter CLKS_PER_BIT = 10400 // 100 MHz Sistem Saati, 9600 Baud Rate
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_pin,
    output reg  [7:0] rx_data,
    output reg        rx_done
);

    // Durum Tanımlamaları (FSM)
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    reg [1:0]  current_state;
    reg [13:0] clk_counter;
    reg [2:0]  bit_index;

    // FSM ve Kayıtçı Mantığı
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            clk_counter   <= 14'd0;
            bit_index     <= 3'd0;
            rx_data       <= 8'd0;
            rx_done       <= 1'b0;
        end else begin
            // rx_done darbeli (pulsed) bir bayraktır; varsayılan olarak 0'dır
            rx_done <= 1'b0;

            case (current_state)

                STATE_IDLE: begin
                    clk_counter <= 14'd0;
                    bit_index   <= 3'd0;

                    // Hattın 0'a düşmesi START bitinin geldiğini gösterir
                    if (rx_pin == 1'b0) begin
                        current_state <= STATE_START;
                    end
                end

                STATE_START: begin
                    // Start bitinin tam ortasına (yarı süresine) kadar say
                    if (clk_counter == (CLKS_PER_BIT / 2)) begin
                        // Parazit kontrolü: Hat hâlâ 0 mı?
                        if (rx_pin == 1'b0) begin
                            current_state <= STATE_DATA;
                            clk_counter   <= 14'd0; // Veri bitlerinin ortasını bulmak için sıfırla!
                        end else begin
                            current_state <= STATE_IDLE; // Sahte sinyal / parazit, başa dön
                        end
                    end else begin
                        clk_counter <= clk_counter + 1'b1;
                    end
                end

                STATE_DATA: begin
                    // Her veri bitinin orta noktası 1 tam bit süresi sonradır
                    if (clk_counter == CLKS_PER_BIT - 1) begin
                        clk_counter        <= 14'd0;
                        rx_data[bit_index] <= rx_pin; // Tam ortadan örneklendi (LSB First)

                        if (bit_index == 3'd7) begin
                            bit_index     <= 3'd0;
                            current_state <= STATE_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_counter <= clk_counter + 1'b1;
                    end
                end

                STATE_STOP: begin
                    // Stop bitinin süresini bekle (Hattın 1 olması beklenir)
                    if (clk_counter == CLKS_PER_BIT - 1) begin
                        if (rx_pin == 1'b1) begin
                            rx_done <= 1'b1; // Veri başarıyla alındı ve hazır
                        end
                        current_state <= STATE_IDLE;
                        clk_counter   <= 14'd0;
                    end else begin
                        clk_counter <= clk_counter + 1'b1;
                    end
                end

                default: current_state <= STATE_IDLE;
            endcase
        end
    end

endmodule
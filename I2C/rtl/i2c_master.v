`timescale 1ns / 1ps

module i2c_master #(
    parameter CLK_DIV = 250 // 100 MHz sistem saatinde ~100-400 kHz I2C hızı için sayaç eşiği
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [6:0] slave_addr,
    input  wire       rw,          // 0: Yazma (Write), 1: Okuma (Read)
    input  wire [7:0] tx_data,
    
    output reg        scl,
    inout  wire       sda,
    output reg        ack_error,
    output reg        done_tick
);

    // FSM Durum Tanımları
    localparam STATE_IDLE     = 3'd0;
    localparam STATE_START    = 3'd1;
    localparam STATE_ADDR     = 3'd2;
    localparam STATE_ACK_ADDR = 3'd3;
    localparam STATE_DATA     = 3'd4;
    localparam STATE_ACK_DATA = 3'd5;
    localparam STATE_STOP     = 3'd6;

    reg [2:0] state;
    reg [1:0] phase;
    reg [7:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg       sda_out;

    // Açık kollektör (Open-drain) sürücü mantığı
    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz;
    wire sda_in = sda;

    // Saat Bölücü: Çeyrek periyot (phase) tick üretimi
    wire clk_tick = (clk_cnt == CLK_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_cnt <= 8'd0;
        else if (state == STATE_IDLE)
            clk_cnt <= 8'd0;
        else if (clk_tick)
            clk_cnt <= 8'd0;
        else
            clk_cnt <= clk_cnt + 1'b1;
    end

    // Ana FSM ve Hat Kontrolü
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= STATE_IDLE;
            phase      <= 2'd0;
            scl        <= 1'b1;
            sda_out    <= 1'b1;
            bit_idx    <= 3'd7;
            shift_reg  <= 8'd0;
            ack_error  <= 1'b0;
            done_tick  <= 1'b0;
        end else begin
            done_tick <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    scl       <= 1'b1;
                    sda_out   <= 1'b1;
                    phase     <= 2'd0;
                    ack_error <= 1'b0;
                    if (start) begin
                        shift_reg <= {slave_addr, rw}; // 7-bit adres + R/W biti
                        state     <= STATE_START;
                    end
                end

                // START: SCL = 1 iken SDA 1 -> 0 düşürülür
                STATE_START: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= 1'b1; scl <= 1'b1; phase <= 2'd1; end
                            2'd1: begin sda_out <= 1'b0; scl <= 1'b1; phase <= 2'd2; end // START düşüşü
                            2'd2: begin sda_out <= 1'b0; scl <= 1'b0; phase <= 2'd3; end
                            2'd3: begin 
                                phase   <= 2'd0;
                                bit_idx <= 3'd7;
                                state   <= STATE_ADDR;
                            end
                        endcase
                    end
                end

                // ADDR: 8 bitlik (Adres + R/W) seri aktarım
                STATE_ADDR: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= shift_reg[bit_idx]; scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin scl <= 1'b1; phase <= 2'd3; end
                            2'd3: begin 
                                scl   <= 1'b0;
                                phase <= 2'd0;
                                if (bit_idx == 3'd0)
                                    state <= STATE_ACK_ADDR;
                                else
                                    bit_idx <= bit_idx - 1'b1;
                            end
                        endcase
                    end
                end

                // ACK_ADDR: Slave'den ilk ACK kontrolü (SDA serbest bırakılır)
                STATE_ACK_ADDR: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= 1'b1; scl <= 1'b0; phase <= 2'd1; end // Hattı serbest bırak
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin 
                                scl <= 1'b1;
                                phase <= 2'd3;
                                if (sda_in != 1'b0) // ACK gelmediyse (NACK)
                                    ack_error <= 1'b1;
                            end
                            2'd3: begin 
                                scl       <= 1'b0;
                                phase     <= 2'd0;
                                bit_idx   <= 3'd7;
                                shift_reg <= tx_data;
                                state     <= STATE_DATA;
                            end
                        endcase
                    end
                end

                // DATA: 8 bitlik veri aktarımı
                STATE_DATA: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= shift_reg[bit_idx]; scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin scl <= 1'b1; phase <= 2'd3; end
                            2'd3: begin 
                                scl   <= 1'b0;
                                phase <= 2'd0;
                                if (bit_idx == 3'd0)
                                    state <= STATE_ACK_DATA;
                                else
                                    bit_idx <= bit_idx - 1'b1;
                            end
                        endcase
                    end
                end

                // ACK_DATA: Veri için Slave ACK kontrolü
                STATE_ACK_DATA: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= 1'b1; scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin 
                                scl <= 1'b1;
                                phase <= 2'd3;
                                if (sda_in != 1'b0)
                                    ack_error <= 1'b1;
                            end
                            2'd3: begin 
                                scl   <= 1'b0;
                                phase <= 2'd0;
                                state <= STATE_STOP;
                            end
                        endcase
                    end
                end

                // STOP: SCL = 1 iken SDA 0 -> 1 yükselir
                STATE_STOP: begin
                    if (clk_tick) begin
                        case (phase)
                            2'd0: begin sda_out <= 1'b0; scl <= 1'b0; phase <= 2'd1; end
                            2'd1: begin sda_out <= 1'b0; scl <= 1'b1; phase <= 2'd2; end
                            2'd2: begin sda_out <= 1'b1; scl <= 1'b1; phase <= 2'd3; end // STOP yükselişi
                            2'd3: begin 
                                phase     <= 2'd0;
                                done_tick <= 1'b1;
                                state     <= STATE_IDLE;
                            end
                        endcase
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
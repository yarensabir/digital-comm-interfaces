`timescale 1ns / 1ps

module i2c_master_rw #(
    parameter CLK_DIV = 250 // 100 MHz sistem saatinde ~100-400 kHz aralığı için
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [6:0] slave_addr,
    input  wire       rw,          // 0: Write (Yazma), 1: Read (Okuma)
    input  wire [7:0] tx_data,
    
    output reg        scl,
    inout  wire       sda,
    output reg [7:0]  rx_data,     // Köleden okunan veri çıkışı
    output reg        ack_error,
    output reg        done_tick
);

    // FSM Durumları
    localparam STATE_IDLE     = 3'd0;
    localparam STATE_START    = 3'd1;
    localparam STATE_ADDR     = 3'd2;
    localparam STATE_ACK_ADDR = 3'd3;
    localparam STATE_DATA     = 3'd4;
    localparam STATE_ACK_DATA = 3'd5;
    localparam STATE_READ     = 3'd6;     // Okuma Durumu
    localparam STATE_SEND_ACK = 3'd7;     // Master ACK/NACK Üretimi
    
    reg state_is_stop; // STOP adımı için bayrak

    reg [2:0] state;
    reg [1:0] phase;
    reg [7:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;
    reg [7:0] rx_shift_reg;
    reg       sda_out;
    reg       op_rw;

    // Açık kollektör SDA kontrolü
    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz;
    wire sda_in = sda;

    // Saat Bölücü
    wire clk_tick = (clk_cnt == CLK_DIV - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            clk_cnt <= 8'd0;
        else if (state == STATE_IDLE && !state_is_stop)
            clk_cnt <= 8'd0;
        else if (clk_tick)
            clk_cnt <= 8'd0;
        else
            clk_cnt <= clk_cnt + 1'b1;
    end

    // Ana FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= STATE_IDLE;
            state_is_stop <= 1'b0;
            phase         <= 2'd0;
            scl           <= 1'b1;
            sda_out       <= 1'b1;
            bit_idx       <= 3'd7;
            shift_reg     <= 8'd0;
            rx_shift_reg  <= 8'd0;
            rx_data       <= 8'd0;
            ack_error     <= 1'b0;
            done_tick     <= 1'b0;
            op_rw         <= 1'b0;
        end else begin
            done_tick <= 1'b0;

            if (state_is_stop) begin
                // STOP Koşulu: SCL=1 iken SDA 0 -> 1
                if (clk_tick) begin
                    case (phase)
                        2'd0: begin sda_out <= 1'b0; scl <= 1'b0; phase <= 2'd1; end
                        2'd1: begin sda_out <= 1'b0; scl <= 1'b1; phase <= 2'd2; end
                        2'd2: begin sda_out <= 1'b1; scl <= 1'b1; phase <= 2'd3; end
                        2'd3: begin
                            phase         <= 2'd0;
                            state_is_stop <= 1'b0;
                            done_tick     <= 1'b1;
                            state         <= STATE_IDLE;
                        end
                    endcase
                end
            end else begin
                case (state)
                    STATE_IDLE: begin
                        scl       <= 1'b1;
                        sda_out   <= 1'b1;
                        phase     <= 2'd0;
                        ack_error <= 1'b0;
                        if (start) begin
                            op_rw     <= rw;
                            shift_reg <= {slave_addr, rw};
                            state     <= STATE_START;
                        end
                    end

                    STATE_START: begin
                        if (clk_tick) begin
                            case (phase)
                                2'd0: begin sda_out <= 1'b1; scl <= 1'b1; phase <= 2'd1; end
                                2'd1: begin sda_out <= 1'b0; scl <= 1'b1; phase <= 2'd2; end
                                2'd2: begin sda_out <= 1'b0; scl <= 1'b0; phase <= 2'd3; end
                                2'd3: begin
                                    phase   <= 2'd0;
                                    bit_idx <= 3'd7;
                                    state   <= STATE_ADDR;
                                end
                            endcase
                        end
                    end

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

                    STATE_ACK_ADDR: begin
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
                                    scl     <= 1'b0;
                                    phase   <= 2'd0;
                                    bit_idx <= 3'd7;
                                    if (op_rw == 1'b0) begin
                                        shift_reg <= tx_data;
                                        state     <= STATE_DATA;
                                    end else begin
                                        sda_out   <= 1'b1; // Okuma için SDA hattını serbest bırak
                                        state     <= STATE_READ;
                                    end
                                end
                            endcase
                        end
                    end

                    // Yazma Modu Durumları
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
                                    scl           <= 1'b0;
                                    phase         <= 2'd0;
                                    state_is_stop <= 1'b1;
                                end
                            endcase
                        end
                    end

                    // Okuma Modu: Köleden gelen bitleri toplama
                    STATE_READ: begin
                        if (clk_tick) begin
                            case (phase)
                                2'd0: begin sda_out <= 1'b1; scl <= 1'b0; phase <= 2'd1; end
                                2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                                2'd2: begin
                                    scl <= 1'b1;
                                    rx_shift_reg[bit_idx] <= sda_in; // Gelen biti kaydet
                                    phase <= 2'd3;
                                end
                                2'd3: begin
                                    scl   <= 1'b0;
                                    phase <= 2'd0;
                                    if (bit_idx == 3'd0) begin
                                        rx_data <= {rx_shift_reg[7:1], sda_in};
                                        state   <= STATE_SEND_ACK;
                                    end else begin
                                        bit_idx <= bit_idx - 1'b1;
                                    end
                                end
                            endcase
                        end
                    end

                    // Okuma Sonu: Master NACK (1'b1) basar
                    STATE_SEND_ACK: begin
                        if (clk_tick) begin
                            case (phase)
                                2'd0: begin sda_out <= 1'b1; scl <= 1'b0; phase <= 2'd1; end
                                2'd1: begin scl <= 1'b1; phase <= 2'd2; end
                                2'd2: begin scl <= 1'b1; phase <= 2'd3; end
                                2'd3: begin
                                    scl           <= 1'b0;
                                    phase         <= 2'd0;
                                    state_is_stop <= 1'b1;
                                end
                            endcase
                        end
                    end

                    default: state <= STATE_IDLE;
                endcase
            end
        end
    end

endmodule
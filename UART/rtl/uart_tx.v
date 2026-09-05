`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,          // 100 MHz ana saat sinyalimiz
    input  wire       rst_n,        // Reset sinyalimiz (0 ise sistem durur)
    input  wire [7:0] tx_data,      // Göndermek istediğin 8 bitlik veri (Örn: 'A' harfi)
    input  wire       tx_start,     // C++'taki "Gönder" butonuna basmak gibi; 1 olunca işlem başlar
    output reg        tx_pin        // Bilgisayara giden o TEK KABLO!
);
// Zamanı milimetrik sayacak kronometre (10400'e kadar sayar)
    reg [13:0] clk_counter;
    // Kaçıncı biti gönderdiğimizi tutan sayaç (0'dan 7'ye kadar sayar)
    reg [2:0]  bit_index;
    // Senin bahsettiğin o saklayıcı! İçeri giren veriyi buraya kopyalayıp koruyacağız.
    reg [7:0]  tx_shift_reg;
    
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP = 2'b11;
    reg [1:0] current_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
            clk_counter   <= 0;
            bit_index     <= 0;
            tx_shift_reg  <= 0;
            tx_pin        <= 1'b1; // UART boşta beklerken hat hep 1'dir!
        end else begin
            case (current_state)
                
                STATE_IDLE: begin
                    tx_pin <= 1'b1; // Boşta beklerken 1 üfle
                    clk_counter <= 0;
                    
                    // Eğer dışarıdan C++ butonuna basılır gibi tx_start gelirse...
                    if (tx_start == 1'b1) begin
                        tx_shift_reg  <= tx_data; // Gelen 8 bitlik veriyi saklayıcıya kilitle
                        current_state <= STATE_START; // START durumuna zıpla!
                    end
                end

                STATE_START: begin
                    tx_pin <= 1'b0; // START biti her zaman 0'dır!
                    
                    // Dün akşam yaptığımız o meşhur sayaç hesabı devreye giriyor:
                    if (clk_counter == 10400 - 1) begin
                        clk_counter   <= 0;
                        bit_index     <= 0;
                        current_state <= STATE_DATA; // 104 mikrosaniye doldu, veriye geç!
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end

                STATE_DATA: begin
                    // İşte senin o "tek kablodan sırayla gönderme" fikrinin koda dökülmüş hali:
                    tx_pin <= tx_shift_reg[bit_index]; // Saklayıcının o anki bitini kabloya ver!
                    
                    if (clk_counter == 10400 - 1) begin
                        clk_counter <= 0;
                        
                        // 8 bitin hepsi bitti mi? (0,1,2,3,4,5,6,7)
                        if (bit_index == 7) begin
                            current_state <= STATE_STOP; // Bittiyse STOP durumuna geç
                        end else begin
                            bit_index <= bit_index + 1; // Bitmediyse sıradaki bite geç!
                        end
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end

                STATE_STOP: begin
                    tx_pin <= 1'b1;
                    if(clk_counter == 10400 - 1)begin
                        clk_counter <= 0;
                        current_state <= STATE_IDLE;
                    end else begin
                        clk_counter <= clk_counter + 1;
                    end
                end
            endcase
        end
    end

    
    
endmodule

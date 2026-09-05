`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/04/2026 04:57:00 PM
// Design Name: 
// Module Name: tb_uart_tx
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module tb_uart_tx();

    // 1. Sinyal Tanımlamaları
    reg        clk;
    reg        rst_n;
    reg [7:0]  tx_data;
    reg        tx_start;
    wire       tx_pin; // Modülden çıkan tek kabloyu izlemek için wire!

    // 2. Test Edeceğimiz Modülü (UUT) Bağlama
    uart_tx uut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_pin(tx_pin)
    );

    // 3. 100 MHz Saat Sinyali Üretimi (Her 5 ns'de bir ters çevir)
    always begin
        #5 clk = ~clk;
    end

    // 4. Ana Senaryo Bloğu
    initial begin
        // Başlangıç Değerleri
        clk = 0;
        rst_n = 0;
        tx_data = 8'h00;
        tx_start = 0;

        #20;
        rst_n = 1; // Resetten çıktık
        #100;
        // Güvenli bölgeye geçiş (Saat kenarlarını yakala)
        @(posedge clk);
        // --- SENARYO BAŞLIYOR ---
        // Bilgisayara 8'b01000001 (Yani 'A' harfi, hex olarak 8'h41) göndermek istiyoruz.
        tx_data = 8'b01000001; 
        
        // Modüle "Hadi Başla" emrini vermek için tx_start sinyalini 1 clock boyunca yakalım
        tx_start = 1;
        @(posedge clk);
        tx_start = 0; // Başlama emrini verdik, geri söndürdük.

        // --- ŞİMDİ SIRA SENDE ---
        // UART paketinin tamamının kablodan akıp gitmesi ne kadar sürüyordu?
        // Hatırla: 1 Start + 8 Data + 1 Stop = Toplam 10 bit gönderiyoruz.
        // Her bit havada 104 mikrosaniye (us) kalıyordu.
        // Yani tüm paketi dalga ekranında görebilmek için simülatörü en az ne kadar bekletmeliyiz?
        
        #11000000; 

        $finish; // Simülasyonu bitir
    end

endmodule
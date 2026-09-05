`timescale 1ns / 1ps

module uart_loopback_tb;

    // 100 MHz Sistem Saati (Periyot = 10 ns)
    reg clk;
    reg rst_n;

    // TX Sinyalleri
    reg  [7:0] tx_data_in;
    reg        tx_start;
    wire       tx_serial_line;

    // RX Sinyalleri
    wire [7:0] rx_data_out;
    wire       rx_done_tick;

    // 1. TX Modülünü Çağırıyoruz (DUT - 1)
    // Senin yazdığın uart_tx portlarıyla birebir eşleşti
    uart_tx u_uart_tx (
        .clk        (clk),
        .rst_n      (rst_n),
        .tx_start   (tx_start),
        .tx_data    (tx_data_in),
        .tx_pin     (tx_serial_line)
    );

    // 2. RX Modülünü Çağırıyoruz (DUT - 2)
    // KRİTİK NOKTA: rx_pin'e doğrudan tx_serial_line bağlanıyor!
    uart_rx u_uart_rx (
        .clk        (clk),
        .rst_n      (rst_n),
        .rx_pin     (tx_serial_line),
        .rx_data    (rx_data_out),
        .rx_done    (rx_done_tick)
    );

    // 100 MHz Saat Üreteci (5ns HIGH, 5ns LOW)
    always #5 clk = ~clk;

    // Test Senaryosu
    initial begin
        // Başlangıç değerleri
        clk        = 1'b0;
        rst_n      = 1'b0;
        tx_start   = 1'b0;
        tx_data_in = 8'h00;

        // Reset uygula (100 ns)
        #100;
        rst_n = 1'b1;
        #100;

        // 1. Test Baytı: 0xA5 (10100101)
        @(posedge clk);
        tx_data_in = 8'hA5;
        tx_start   = 1'b1;
        
        @(posedge clk);
        tx_start   = 1'b0; // Start sinyalini darbe (pulse) yapıp geri çekiyoruz

        // RX'in işi bitirmesini (rx_done_tick gelmesini) bekle
        @(posedge rx_done_tick);

        // Self-Checking (Otomatik Denetim) Mantığı
        if (rx_data_out == 8'hA5) begin
            $display("[BAŞARILI] Saat gibi çalıştı! Gönderilen: 0x%h, Alınan: 0x%h", tx_data_in, rx_data_out);
        end else begin
            $display("[HATA] Veri bozuldu! Gönderilen: 0x%h, Alınan: 0x%h", tx_data_in, rx_data_out);
        end

        #5000;
        $finish; // Simülasyonu sonlandır
    end

endmodule
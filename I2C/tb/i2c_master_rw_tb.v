`timescale 1ns / 1ps

module i2c_master_rw_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [6:0] slave_addr;
    reg        rw;
    reg  [7:0] tx_data;
    
    wire       scl;
    wire       sda;
    wire [7:0] rx_data;
    wire       ack_error;
    wire       done_tick;

    // Pull-up direnci: Hat boştayken '1' olur
    pullup(sda);

    // Sanal Köle Sürücüsü (ACK veya Veri biti basar)
    reg slave_drive_low;
    assign sda = (slave_drive_low) ? 1'b0 : 1'bz;

    // UUT Örneği
    i2c_master_rw #(
        .CLK_DIV(10) // Hızlı simülasyon
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .tx_data(tx_data),
        .scl(scl),
        .sda(sda),
        .rx_data(rx_data),
        .ack_error(ack_error),
        .done_tick(done_tick)
    );

    // 100 MHz Saat
    always #5 clk = ~clk;

    // Sanal Sensör Verisi (Kölenin Master'a göndereceği bayt: 0xA5 = 10100101)
    localparam [7:0] SENSOR_DATA = 8'hA5;

    // Sanal Köle Davranış Modeli
    always @(*) begin
        // Master ACK bekliyorsa (STATE_ACK_ADDR) köle hattı 0'a çeker
        if (uut.state == 3'd3) begin
            slave_drive_low = 1'b1;
        end
        // Master Okuma durumundaysa (STATE_READ), köle sensör verisini basar
        else if (uut.state == 3'd6) begin
            // Bit '0' ise hattı toprağa çek, '1' ise serbest (Z) bırak
            if (SENSOR_DATA[uut.bit_idx] == 1'b0)
                slave_drive_low = 1'b1;
            else
                slave_drive_low = 1'b0;
        end
        else begin
            slave_drive_low = 1'b0;
        end
    end

    // Test Akışı
    initial begin
        clk             = 1'b0;
        rst_n           = 1'b0;
        start           = 1'b0;
        slave_addr      = 7'h50; // Sensör adresi
        rw              = 1'b1;  // 1: OKUMA MODU
        tx_data         = 8'h00;
        slave_drive_low = 1'b0;

        #100;
        rst_n = 1'b1;
        #50;

        // Okuma işlemini başlat
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // İşlem tamamlanana kadar bekle
        @(posedge done_tick);
        #100;

        // Doğrulama Kontrolü
        if (!ack_error && rx_data == SENSOR_DATA) begin
            $display("=================================================");
            $display("[SUCCESS] I2C Read Successful!");
            $display("Read Data = 0x%02X (Expected: 0x%02X)", rx_data, SENSOR_DATA);
            $display("=================================================");
        end else begin
            $display("=================================================");
            $display("[FAIL] Read failed or data mismatch!");
            $display("Read Data = 0x%02X (Expected: 0x%02X), ack_error = %b", rx_data, SENSOR_DATA, ack_error);
            $display("=================================================");
        end

        #200;
        $finish;
    end

endmodule
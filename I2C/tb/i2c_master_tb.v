`timescale 1ns / 1ps

module i2c_master_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [6:0] slave_addr;
    reg        rw;
    reg  [7:0] tx_data;
    
    wire       scl;
    wire       sda;
    wire       ack_error;
    wire       done_tick;

    // Tek bir pull-up: Hat boştayken '1' olur
    pullup(sda);

    // Sanal Slave: ACK basacağı zaman 0 çeker, basmayacağı zaman Z bırakır
    reg slave_ack;
    assign sda = (slave_ack) ? 1'b0 : 1'bz;

    // Master Modülü
    i2c_master #(
        .CLK_DIV(10)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .tx_data(tx_data),
        .scl(scl),
        .sda(sda),
        .ack_error(ack_error),
        .done_tick(done_tick)
    );

    // 100 MHz Saat
    always #5 clk = ~clk;

    // Sanal Slave: Master ACK bekleme durumlarındayken (STATE_ACK_ADDR ve STATE_ACK_DATA) SDA'yı 0'a çeker
    always @(*) begin
        if (uut.state == 3'd3 || uut.state == 3'd5)
            slave_ack = 1'b1;
        else
            slave_ack = 1'b0;
    end

    // Test Akışı
    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        start      = 1'b0;
        slave_addr = 7'h50;
        rw         = 1'b0;
        tx_data    = 8'h3C;
        slave_ack  = 1'b0;

        #100;
        rst_n = 1'b1;
        #50;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // done_tick sinyalini bekle
        @(posedge done_tick);
        #200;

        if (!ack_error)
            $display("[SUCCESS] I2C write transaction completed with ACK!");
        else
            $display("[ERROR] Transaction failed with NACK!");

        $finish;
    end

endmodule
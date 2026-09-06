`timescale 1ns / 1ps

module spi_master_tb;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] tx_data;
    reg        miso;

    wire       sck;
    wire       mosi;
    wire       cs;
    wire [7:0] rx_data;
    wire       done_tick;

    spi_master #(
        .CLK_DIV(4)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .miso(miso),
        .sck(sck),
        .mosi(mosi),
        .cs(cs),
        .rx_data(rx_data),
        .done_tick(done_tick)
    );

    always #5 clk = ~clk;

    // Sanal Slave: CS düşünce hemen MSB'yi (0x89'un '1'ini) hatta sürer
    reg [7:0] slave_tx_reg;

    always @(negedge sck or posedge cs) begin
        if (cs) begin
            slave_tx_reg <= 8'h89;
            miso         <= 1'b1; 
        end else begin
            miso         <= slave_tx_reg[6];
            slave_tx_reg <= {slave_tx_reg[5:0], 1'b0};
        end
    end

    initial begin
        clk     = 0;
        rst_n   = 0;
        start   = 0;
        tx_data = 8'h00;
        miso    = 0;

        #20;
        rst_n = 1;
        #20;

        $display("[TB] SPI Transferi Baslatiliyor. Gonderilen: 0x3C");
        @(posedge clk);
        tx_data <= 8'h3C;
        start   <= 1'b1;
        @(posedge clk);
        start   <= 1'b0;

        @(posedge done_tick);
        #20;

        if (rx_data == 8'h89) begin
            $display("[TB] BASARILI: MISO uzerinden okunan veri dogru! (rx_data = 0x%h)", rx_data);
        end else begin
            $display("[TB] HATA: Beklenen 0x89, okunan 0x%h", rx_data);
        end

        #50;
        $finish;
    end

endmodule
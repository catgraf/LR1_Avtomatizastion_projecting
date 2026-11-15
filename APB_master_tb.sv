`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

// Изолированный тест APB-мастера с заглушечным слейвом.
// Проверяет: обычную транзакцию, wait states, обработку pslverr.
module tb_master;

    logic        pclk;
    logic        presetn;

    // хост-интерфейс к мастеру
    logic        req;
    logic        wr;
    logic [31:0] addr;
    logic [31:0] wdata;
    wire  [31:0] rdata;
    wire         ready;
    wire         err;

    // APB-шина
    wire         psel;
    wire         penable;
    wire         pwrite;
    wire  [31:0] paddr;
    wire  [31:0] pwdata;
    wire  [31:0] prdata;
    wire         pready;
    wire         pslverr;

    // конфигурация dummy_slave
    logic [3:0]  wait_cycles;
    logic        inject_err;

    // служебные переменные TB
    logic [31:0] data_from_device;
    logic        err_captured; // захват err на момент ready=1

    // инстанс мастера
    apb_master MASTER (
        .pclk    (pclk),
        .presetn (presetn),
        .req     (req),
        .wr      (wr),
        .addr    (addr),
        .wdata   (wdata),
        .rdata   (rdata),
        .ready   (ready),
        .err     (err),
        .psel    (psel),
        .penable (penable),
        .pwrite  (pwrite),
        .paddr   (paddr),
        .pwdata  (pwdata),
        .prdata  (prdata),
        .pready  (pready),
        .pslverr (pslverr)
    );

    // инстанс заглушки-слейва
    dummy_slave SLAVE (
        .pclk        (pclk),
        .presetn     (presetn),
        .psel        (psel),
        .penable     (penable),
        .pwrite      (pwrite),
        .paddr       (paddr),
        .pwdata      (pwdata),
        .prdata      (prdata),
        .pready      (pready),
        .pslverr     (pslverr),
        .wait_cycles (wait_cycles),
        .inject_err  (inject_err)
    );

    // захват err, пока ready=1 (иначе err сбросится в IDLE на следующем такте)
    always @(posedge pclk)
        if (ready && err)
            err_captured <= 1'b1;

    // задача записи
    task apb_write(input [31:0] a, input [31:0] d);
        wait (ready == 1'b0);
        @(posedge pclk);
        req   <= 1'b1;
        wr    <= 1'b1;
        addr  <= a;
        wdata <= d;
        wait (ready == 1'b1);
        req   <= 1'b0;
        wait (ready == 1'b0);
    endtask

    // задача чтения
    task apb_read(input [31:0] a, output logic [31:0] d);
        wait (ready == 1'b0);
        @(posedge pclk);
        req   <= 1'b1;
        wr    <= 1'b0;
        addr  <= a;
        wait (ready == 1'b1);
        d = rdata;
        req   <= 1'b0;
        wait (ready == 1'b0);
    endtask

    // генератор тактового сигнала
    always #10 pclk = ~pclk;

    // основной сценарий
    initial begin
        pclk         = 1'b0;
        presetn      = 1'b1;
        req          = 1'b0;
        wr           = 1'b0;
        addr         = '0;
        wdata        = '0;
        wait_cycles  = 4'd0;
        inject_err   = 1'b0;
        err_captured = 1'b0;

        repeat (5) @(posedge pclk);
            presetn = 1'b0;
        repeat (5) @(posedge pclk);
            presetn = 1'b1;
        repeat (5) @(posedge pclk);

        // T1: обычная запись/чтение, wait_cycles=0
        err_captured = 1'b0;
        apb_write(32'h1000, 32'hDEAD_BEEF);
        apb_read (32'h1000, data_from_device);
        if (data_from_device !== 32'h21524110)  // ~DEADBEEF
            $error("[TB_MASTER] FAIL T1: rdata=0x%08h, expected 0x21524110", data_from_device);
        else if (err_captured !== 1'b0)
            $error("[TB_MASTER] FAIL T1: err unexpectedly set");
        else
            $display("[TB_MASTER] PASS T1: normal write/read");

        // T2: wait states = 5
        wait_cycles  = 4'd5;
        err_captured = 1'b0;
        apb_write(32'h2000, 32'hCAFE_F00D);
        apb_read (32'h2000, data_from_device);
        if (data_from_device !== 32'h35010FF2)  // ~CAFEF00D
            $error("[TB_MASTER] FAIL T2: rdata=0x%08h, expected 0x35010FF2", data_from_device);
        else if (err_captured !== 1'b0)
            $error("[TB_MASTER] FAIL T2: err unexpectedly set");
        else
            $display("[TB_MASTER] PASS T2: wait_states=5");

        // T3: pslverr=1 в транзакции
        wait_cycles  = 4'd0;
        inject_err   = 1'b1;
        err_captured = 1'b0;
        apb_write(32'h3000, 32'h11111111);
        if (err_captured !== 1'b1)
            $error("[TB_MASTER] FAIL T3: err not captured");
        else
            $display("[TB_MASTER] PASS T3: inject_err");

        repeat (10) @(posedge pclk);
        $finish();
    end

endmodule

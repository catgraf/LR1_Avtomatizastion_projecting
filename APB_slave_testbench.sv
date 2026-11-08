`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

module TB;

  // Сигналы интерфейса APB
  logic        pclk;
  logic        presetn;
  logic        psel;
  logic        penable;
  logic        pwrite;
  logic [31:0] paddr;
  logic [31:0] pwdata;
  wire  [31:0] prdata;
  wire         pready;
  wire         pslverr;

  // Параметры
  parameter bit [31:0] p_device_offset = 32'h7000_0000;

  // Внутренние переменные тестбенча
  logic [31:0] address;
  logic [31:0] data_to_device;
  logic [31:0] data_from_device;

  // Экземпляр тестируемого устройства (DUT)
  apb_slave DUT (
    .pclk   (pclk),    // Синхросигнал
    .presetn(presetn), // Сигнал сброса (инверсный)
    .paddr  (paddr),   // Адрес обращения
    .pwdata (pwdata),  // Данные для записи
    .psel   (psel),    // Признак выбора устройства
    .penable(penable), // Признак активной транзакции
    .pwrite (pwrite),  // Признак операции записи
    .pready (pready),  // Признак готовности от устройства
    .pslverr(pslverr), // Опциональный сигнал: признак ошибки при обращении
    .prdata (prdata)   // Прочитанные данные
  );

  // Задача записи по протоколу APB
  task apb_write(input [31:0] addr, input [31:0] data);
    wait ((penable == 1'b0) && (pready == 1'b0));
    @(posedge pclk);
        psel         <= 1'b1;
        paddr[31:0]  <= addr[31:0];
        pwdata[31:0] <= data[31:0];
        pwrite       <= 1'b1;
    @(posedge pclk);
        penable      <= 1'b1;
    @(posedge pclk);
        wait (pready == 1'b1);
    @(posedge pclk);
        psel         <= 1'b0;
        penable      <= 1'b0;
        pwrite       <= 1'b0;
    @(posedge pclk);
  endtask

  // Задача чтения по протоколу APB
  task apb_read(input [31:0] addr, output logic [31:0] data);
    wait ((penable == 1'b0) && (pready == 1'b0));
    @(posedge pclk);
        psel        <= 1'b1;
        pwrite      <= 1'b0;
        paddr[31:0] <= addr[31:0];
    @(posedge pclk);
        penable     <= 1'b1;
    @(posedge pclk);
        wait (pready == 1'b1);
    @(posedge pclk);
        data[31:0]  <= prdata[31:0];
        psel        <= 1'b0;
        penable     <= 1'b0;
    @(posedge pclk);
  endtask

  // Генератор тактового сигнала (период 20 нс)
  always #10 pclk = ~pclk;

  // Основной сценарий теста
  initial begin
    pclk    = 1'b0;
    presetn = 1'b1;

    psel    = '0;
    penable = '0;
    pwrite  = '0;
    paddr   = '0;
    pwdata  = '0;
    
    repeat (5) @(posedge pclk);
        presetn = 1'b0;
    repeat (5) @(posedge pclk);
        presetn = 1'b1;
    repeat (5) @(posedge pclk);

    // Тест 1: Запись и чтение 32'h12345678
    address = p_device_offset + 0;
    data_to_device = 32'h12345678;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);

    // Тест 2: Запись и чтение 32'h1
    data_to_device = 32'h1;
    apb_write(address, data_to_device);
    apb_read(address, data_from_device);
    $display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
    // неверный адрес -> pslverr=1, затем верный -> pslverr должен сброситься
    address = p_device_offset + 32'h10;  // 0x10 не декодируется -> default
    data_to_device = 32'hDEAD_BEEF;
    apb_write(address, data_to_device);

    address = p_device_offset + 0;       // верный адрес -> APB_SETUP сбросит pslverr
    apb_read(address, data_from_device);
    if (pslverr !== 1'b0)
        $error("[TB] FAIL: pslverr not cleared after valid access, got %b", pslverr);
    else
        $display("[TB] PASS: pslverr cleared after valid access");
    repeat (10) @(posedge pclk);
    //$stop();
    $finish();
  end

  // Мониторинг состояния интерфейса
  initial begin
    $monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", 
             penable, pready, paddr, pwdata, prdata);
  end

endmodule

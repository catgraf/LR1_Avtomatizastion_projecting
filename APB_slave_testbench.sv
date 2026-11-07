
module TB;

logic pclk;
logic presetn;
logic psel;
logic penable;
logic pwrite;
logic [31:0] paddr;
logic [31:0] pwdata;
wire [31:0] prdata;
wire pready;
wire pslverr;

parameter p_device_offset = 32'h7000_0000;

logic [31:0] address;
logic [31:0] data_to_device;
logic [31:0] data_from_device;


apb_slave DUT
(
.pclk(pclk), //синхросигнал
.presetn, //сигнал сброса (инверсный)
.paddr(paddr), //адрес обращения
.pwdata(pwdata), //данные для записи
.psel(psel), // признак выбора устройсва
.penable(penable), //признак активной транзакции
.pwrite(pwrite), // признак операции записи
.pready(pready), // признак готовности от устройства
.pslverr(pslverr), // опциональный сигнал: признак ошибки при обращении
.prdata(prdata) // прочитанные данные
);





task apb_write(input [31:0] addr, [31:0] data);
wait ((penable==0) && (pready == 0));
@(posedge pclk);
psel <= 1'b1;
paddr[31:0] <= addr[31:0];
pwdata[31:0] <= data[31:0];
pwrite <= 1'b1;
@(posedge pclk);
penable <= 1'b1;
@(posedge pclk);
wait (pready == 1'b1);
@(posedge pclk);
psel <= 1'b0;
penable <= 1'b0;
pwrite <= 1'b0;
@(posedge pclk);
endtask

task apb_read(input [31:0] addr, output logic [31:0] data);
wait ((penable==0) && (pready == 0));
@(posedge pclk);
psel <= 1'b1;
pwrite <= 1'b0;
paddr[31:0] <= addr[31:0];
@(posedge pclk);
penable <= 1'b1;
@(posedge pclk);
wait (pready == 1'b1);
@(posedge pclk);
data[31:0]<=prdata[31:0];
psel <= 1'b0;
penable <= 1'b0;
@(posedge pclk);
endtask

always
#10ns pclk=~pclk;

initial
begin
pclk=0;
presetn=1'b1;


psel='0;
penable='0;
pwrite='0;
paddr='0;
pwdata='0;
repeat (5) @(posedge pclk);
presetn=1'b0;
repeat (5) @(posedge pclk);
presetn=1'b1;
repeat (5) @(posedge pclk);
address = p_device_offset+0;
data_to_device = 32'h12345678;
apb_write(address, data_to_device);
apb_read(address, data_from_device);
$display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
data_to_device = 32'h1;
apb_write(address, data_to_device);
apb_read(address, data_from_device);
$display("Addr= 0x%h, write data 0x%h, read data 0x%h", address, data_to_device, data_from_device);
repeat (10) @(posedge pclk);
$stop();
end


initial
begin
$monitor("APB IF state: PENABLE=%b PREADY=%b PADDR=0x%h PWDATA=0x%h PRDATA=0x%h", penable, pready, paddr, pwdata, prdata);
end
endmodule

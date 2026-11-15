`timescale 1ns/1ps //единица времени — 1 нс, точность — 1 пс

// Заглушечный APB-слейв для изолированного тестирования мастера.
// Отвечает через заданное число тактов (wait_cycles), возвращает
// инвертированные данные при чтении, умеет форсировать pslverr.
module dummy_slave (
    input               pclk,        // синхросигнал
    input               presetn,     // сигнал сброса (инверсный)
    // интерфейс APB
    input               psel,        // признак выбора устройства
    input               penable,     // признак активной транзакции
    input               pwrite,      // признак операции записи
    input        [31:0] paddr,       // адрес обращения (не декодируется)
    input        [31:0] pwdata,      // данные для записи
    output logic [31:0] prdata,      // прочитанные данные
    output logic        pready,      // признак готовности
    output logic        pslverr,     // признак ошибки
    // конфигурация (управляется из TB)
    input        [3:0]  wait_cycles, // сколько тактов тянуть pready=0
    input               inject_err   // 1 — выставить pslverr в транзакции
);

    // FSM заглушки
    enum logic [1:0] {
        IDLE,    // ждём psel+penable
        ACCESS,  // отсчитываем wait_cycles
        DONE     // pready был 1, ждём снятия psel
    } st;

    logic [3:0]  counter;       // счётчик тактов ожидания
    logic [31:0] last_wdata;    // последнее записанное слово (для чтения)

    always @(posedge pclk) begin
        if (!presetn) begin
            prdata     <= '0;
            pready     <= 1'b0;
            pslverr    <= 1'b0;
            counter    <= '0;
            last_wdata <= '0;
            st         <= IDLE;
        end else begin
            case (st)

                IDLE: begin: dummy_idle_st
                    pready  <= 1'b0;
                    pslverr <= 1'b0;
                    // старт транзакции: psel=1 и penable=1
                    if (psel && penable) begin
                        counter <= wait_cycles;
                        st      <= ACCESS;
                    end
                end: dummy_idle_st

                ACCESS: begin: dummy_access_st
                    // отсчитываем такты ожидания
                    if (counter == 4'd0) begin
                        pready  <= 1'b1;
                        pslverr <= inject_err;
                        if (pwrite)
                            last_wdata <= pwdata;
                        else
                            prdata <= ~last_wdata; // инверсия для наглядности
                        st <= DONE;
                    end else begin
                        counter <= counter - 4'd1;
                    end
                end: dummy_access_st

                DONE: begin: dummy_done_st
                    // снимаем pready, ждём окончания транзакции
                    pready  <= 1'b0;
                    pslverr <= 1'b0;
                    if (!psel)
                        st <= IDLE;
                end: dummy_done_st

                default: st <= IDLE;
            endcase
        end
    end

endmodule

`timescale 1ns/1ps
module DisplayLCD (
    //Entradas
    input CLK,                  //Reloj de 50 MHz
    input RST,                  //Reset activo en bajo (KEY1)
    //Salidas
    output E,
    output reg RS,
    output RW,
    output reg INIlisto,
    output reg [7:0] DATOS
);

    //Nombres de los estados
    parameter Espera_20ms           = 4'b0000;
    parameter Enviar_SetFunction    = 4'b0001;
    parameter Envia_EntryModeSet    = 4'b0010;
    parameter Enviar_DisplayControl = 4'b0011;
    parameter Envia_DisplayClear    = 4'b0100;
    parameter Envia_Direccion       = 4'b0101;
    parameter Envia_Caracter        = 4'b0110;
    parameter Caracter1             = 4'b0111;
    parameter Caracter2             = 4'b1000;
    parameter Caracter3             = 4'b1001;
    parameter Caracter4             = 4'b1010;
    parameter Termina_Aqui          = 4'b1011;

    reg [3:0]  estado;
    reg [16:0] contador;
    reg [4:0]  cuentas;
    reg        en_fsm;
    reg        clk_e;
    wire       nrst = ~RST;
    wire       tick = (contador == 17'd0);    //Un pulso por estado (cada ~2 ms)

    assign RW = 1'b0;                         //Modo del display: ESCRITURA

    //Contador: 100001 ciclos de 50 MHz = ~2 ms por estado
    always @ (posedge CLK or posedge nrst)
        if (nrst) contador <= 17'd0;
        else if (contador == 17'd100000) contador <= 17'd0;
        else contador <= contador + 1'b1;

    //Ventana de E: centrada en el estado (RS y DATOS estables antes y después)
    always @ (posedge CLK)
        clk_e <= (contador >= 17'd25000) && (contador < 17'd75000);

    assign E = en_fsm ? (clk_e & en_fsm) : en_fsm;

    //Máquina de estados (FSM)
    always @ (posedge CLK or posedge nrst)
        if (nrst) begin
            INIlisto <= 1'b0;
            RS       <= 1'b0;
            en_fsm   <= 1'b0;
            DATOS    <= 8'b00000000;
            cuentas  <= 5'd0;
            estado   <= Espera_20ms;
        end
        else if (tick) begin
            case (estado)
                Espera_20ms: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b0;
                    DATOS <= 8'b00000000;
                    if (cuentas < 5'd15) cuentas <= cuentas + 1'b1;   //16 estados = ~32 ms
                    else begin
                        cuentas <= 5'd0;
                        estado  <= Enviar_SetFunction;
                    end
                end
                Enviar_SetFunction: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b1;
                    DATOS <= 8'b0011_1000;      //38H
                    estado <= Envia_EntryModeSet;
                end
                Envia_EntryModeSet: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b1;
                    DATOS <= 8'b0000_0110;      //06H
                    estado <= Enviar_DisplayControl;
                end
                Enviar_DisplayControl: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b1;
                    DATOS <= 8'b0000_1110;      //0EH
                    estado <= Envia_DisplayClear;
                end
                Envia_DisplayClear: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b1;
                    DATOS <= 8'b0000_0001;      //01H
                    estado <= Envia_Direccion;
                end
                Envia_Direccion: begin
                    INIlisto <= 1'b0; RS <= 1'b0; en_fsm <= 1'b1;
                    DATOS <= 8'b1000_0000;      //80H: DDRAM en la dirección 00H
                    estado <= Envia_Caracter;
                end
                Envia_Caracter: begin
                    INIlisto <= 1'b1; RS <= 1'b1; en_fsm <= 1'b1;
                    DATOS <= 8'b0010_0000;      //Espacio (20H)
                    estado <= Caracter1;
                end
                Caracter1: begin
                    INIlisto <= 1'b1; RS <= 1'b1; en_fsm <= 1'b1;
                    DATOS <= 8'b0100_1000;      //Carácter H
                    estado <= Caracter2;
                end
                Caracter2: begin
                    INIlisto <= 1'b1; RS <= 1'b1; en_fsm <= 1'b1;
                    DATOS <= 8'b0100_1111;      //Carácter O
                    estado <= Caracter3;
                end
                Caracter3: begin
                    INIlisto <= 1'b1; RS <= 1'b1; en_fsm <= 1'b1;
                    DATOS <= 8'b0100_1100;      //Carácter L
                    estado <= Caracter4;
                end
                Caracter4: begin
                    INIlisto <= 1'b1; RS <= 1'b1; en_fsm <= 1'b1;
                    DATOS <= 8'b0100_0001;      //Carácter A
                    estado <= Termina_Aqui;
                end
                Termina_Aqui: begin
                    INIlisto <= 1'b1; RS <= 1'b0; en_fsm <= 1'b0;   //Fin de tarea
                    DATOS <= 8'b00000000;
                    estado <= Termina_Aqui;
                end
                default: estado <= Espera_20ms;
            endcase
        end
endmodule
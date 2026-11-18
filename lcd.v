module lcd (
    input  wire        clk,          // Clock de 50 MHz da DE2-115
    input  wire        sistema_on,   // 1 = CPU ligada, 0 = CPU desligada
    input  wire        atualizar,    // Pulso de 1 ciclo quando uma instrução termina
    input  wire        tela_inicial, // 1 = exibe "------ [----] / +00000"
    input  wire [2:0]  opcode,       // Opcode da instrução executada
    input  wire [3:0]  reg_dest,     // Endereço do registrador mostrado entre [ ]
    input  wire [15:0] valor_16b,    // Resultado da ULA (ou valor lido no DISPLAY)
    output reg  [7:0]  lcd_data,
    output reg         lcd_rs,
    output reg         lcd_rw,
    output reg         lcd_en
);

    // Opcodes
    localparam OP_LOAD    = 3'b000,
               OP_ADD     = 3'b001,
               OP_ADDI    = 3'b010,
               OP_SUB     = 3'b011,
               OP_SUBI    = 3'b100,
               OP_MUL     = 3'b101,
               OP_CLEAR   = 3'b110,
               OP_DISPLAY = 3'b111;

    // Estados da máquina de envio ao LCD
    localparam ST_IDLE      = 3'd0,
               ST_INIT      = 3'd1,
               ST_WRITE_ALL = 3'd2,
               ST_OFF       = 3'd3;

    reg [2:0]  estado = ST_OFF;
    reg [5:0]  passo;
    reg [16:0] cnt_tempo; // Conta até 100.000 ciclos (2 ms em 50 MHz)
    reg        sistema_on_prev;

    // Conversão de complemento de 2 (16 bits) para sinal + magnitude decimal (5 dígitos)
    wire        negativo = valor_16b[15];
    wire [15:0] abs_val  = negativo ? (~valor_16b + 16'd1) : valor_16b;

    wire [3:0] d4 = (abs_val / 16'd10000) % 10;
    wire [3:0] d3 = (abs_val / 16'd1000)  % 10;
    wire [3:0] d2 = (abs_val / 16'd100)   % 10;
    wire [3:0] d1 = (abs_val / 16'd10)    % 10;
    wire [3:0] d0 =  abs_val              % 10;

    // Texto de 5 caracteres para a operação
    reg [39:0] op_texto;
    always @(*) begin
        case (opcode)
            OP_LOAD:    op_texto = "LOAD ";
            OP_ADD:     op_texto = "ADD  ";
            OP_ADDI:    op_texto = "ADDI ";
            OP_SUB:     op_texto = "SUB  ";
            OP_SUBI:    op_texto = "SUBI ";
            OP_MUL:     op_texto = "MUL  ";
            OP_CLEAR:   op_texto = "CLEAR";
            OP_DISPLAY: op_texto = "DPL  ";
            default:    op_texto = "     ";
        endcase
    end

    // Seleciona o caractere ASCII (0 a 31) correspondente à posição atual da tela
    reg [7:0] char_atual;
    always @(*) begin
        if (tela_inicial) begin
            case (passo)
                // Linha 1: "------    [----]"
                6'd1, 6'd2, 6'd3, 6'd4, 6'd5, 6'd6: char_atual = "-";
                6'd11: char_atual = "[";
                6'd12, 6'd13, 6'd14, 6'd15: char_atual = "-";
                6'd16: char_atual = "]";
                // Linha 2: "          +00000"
                6'd28: char_atual = "+";
                6'd29, 6'd30, 6'd31, 6'd32, 6'd33: char_atual = "0";
                default: char_atual = " ";
            endcase
        end else begin
            case (passo)
                // Linha 1: Nome da operação (colunas 0 a 4)
                6'd1: char_atual = op_texto[39:32];
                6'd2: char_atual = op_texto[31:24];
                6'd3: char_atual = op_texto[23:16];
                6'd4: char_atual = op_texto[15:8];
                6'd5: char_atual = op_texto[7:0];

                // Linha 1: Registrador [XXXX] (colunas 10 a 15) - oculto no CLEAR
                6'd11: char_atual = (opcode == OP_CLEAR) ? " " : "[";
                6'd12: char_atual = (opcode == OP_CLEAR) ? " " : (reg_dest[3] ? "1" : "0");
                6'd13: char_atual = (opcode == OP_CLEAR) ? " " : (reg_dest[2] ? "1" : "0");
                6'd14: char_atual = (opcode == OP_CLEAR) ? " " : (reg_dest[1] ? "1" : "0");
                6'd15: char_atual = (opcode == OP_CLEAR) ? " " : (reg_dest[0] ? "1" : "0");
                6'd16: char_atual = (opcode == OP_CLEAR) ? " " : "]";

                // Linha 2: Sinal + 5 dígitos (colunas 10 a 15) - oculto no CLEAR
                6'd28: char_atual = (opcode == OP_CLEAR) ? " " : (negativo ? "-" : "+");
                6'd29: char_atual = (opcode == OP_CLEAR) ? " " : (8'h30 + {4'd0, d4});
                6'd30: char_atual = (opcode == OP_CLEAR) ? " " : (8'h30 + {4'd0, d3});
                6'd31: char_atual = (opcode == OP_CLEAR) ? " " : (8'h30 + {4'd0, d2});
                6'd32: char_atual = (opcode == OP_CLEAR) ? " " : (8'h30 + {4'd0, d1});
                6'd33: char_atual = (opcode == OP_CLEAR) ? " " : (8'h30 + {4'd0, d0});

                default: char_atual = " ";
            endcase
        end
    end

    // Máquina de estados com geração de pulso ENABLE (negedge em 0,5 ms; espera até 2 ms)
    always @(posedge clk) begin
        sistema_on_prev <= sistema_on;
        lcd_rw <= 1'b0; // Sempre em modo escrita

        // Detecta borda de ligar/desligar o sistema
        if (sistema_on && !sistema_on_prev) begin
            estado    <= ST_INIT;
            passo     <= 6'd0;
            cnt_tempo <= 17'd0;
        end else if (!sistema_on && sistema_on_prev) begin
            estado    <= ST_OFF;
            passo     <= 6'd0;
            cnt_tempo <= 17'd0;
        end else begin
            case (estado)
                ST_OFF: begin
                    // Envia comando 0x08 (Display OFF) uma vez e mantém EN em 0
                    if (passo == 6'd0) begin
                        lcd_rs   <= 1'b0;
                        lcd_data <= 8'h08;
                        if (cnt_tempo == 17'd0)          lcd_en <= 1'b1;
                        else if (cnt_tempo == 17'd25000) lcd_en <= 1'b0; // negedge

                        if (cnt_tempo >= 17'd99999) begin
                            cnt_tempo <= 17'd0;
                            passo     <= 6'd1;
                        end else begin
                            cnt_tempo <= cnt_tempo + 17'd1;
                        end
                    end
                end

                ST_INIT: begin
                    // Sequência obrigatória de inicialização do HD44780
                    lcd_rs <= 1'b0;
                    case (passo)
                        6'd0: lcd_data <= 8'h38; // Modo 8 bits, 2 linhas, 5x8
                        6'd1: lcd_data <= 8'h0C; // Display ON, sem cursor
                        6'd2: lcd_data <= 8'h06; // Incrementa cursor à direita
                        6'd3: lcd_data <= 8'h01; // Limpa display
                    endcase

                    if (cnt_tempo == 17'd0)          lcd_en <= 1'b1;
                    else if (cnt_tempo == 17'd25000) lcd_en <= 1'b0; // negedge

                    if (cnt_tempo >= 17'd99999) begin
                        cnt_tempo <= 17'd0;
                        if (passo == 6'd3) begin
                            passo  <= 6'd0;
                            estado <= ST_WRITE_ALL; // Já desenha a tela inicial
                        end else begin
                            passo <= passo + 6'd1;
                        end
                    end else begin
                        cnt_tempo <= cnt_tempo + 17'd1;
                    end
                end

                ST_WRITE_ALL: begin
                    // Passo 0: posiciona na Linha 1 (0x80)
                    // Passos 1..16: escreve 16 chars da Linha 1
                    // Passo 17: posiciona na Linha 2 (0xC0)
                    // Passos 18..33: escreve 16 chars da Linha 2
                    if (passo == 6'd0) begin
                        lcd_rs   <= 1'b0;
                        lcd_data <= 8'h80;
                    end else if (passo == 6'd17) begin
                        lcd_rs   <= 1'b0;
                        lcd_data <= 8'hC0;
                    end else begin
                        lcd_rs   <= 1'b1;
                        lcd_data <= char_atual;
                    end

                    if (cnt_tempo == 17'd0)          lcd_en <= 1'b1;
                    else if (cnt_tempo == 17'd25000) lcd_en <= 1'b0; // negedge

                    if (cnt_tempo >= 17'd99999) begin
                        cnt_tempo <= 17'd0;
                        if (passo == 6'd33) begin
                            passo  <= 6'd0;
                            estado <= ST_IDLE;
                        end else begin
                            passo <= passo + 6'd1;
                        end
                    end else begin
                        cnt_tempo <= cnt_tempo + 17'd1;
                    end
                end

                ST_IDLE: begin
                    lcd_en    <= 1'b0;
                    cnt_tempo <= 17'd0;
                    passo     <= 6'd0;
                    if (atualizar) begin
                        estado <= ST_WRITE_ALL;
                    end
                end
            endcase
        end
    end
endmodule
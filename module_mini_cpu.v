module module_mini_cpu (
input wire clk,
input wire on_off,
input wire enviar,
input wire [17:0] data,
output wire [7:0] lcd_data,
output wire lcd_rs,
output wire lcd_rw,
output wire lcd_en,
output wire lcd_on
);
wire [15:0] alu_result;
wire [15:0] mem_q;
reg [15:0] reg_val1;

reg         mem_we;
reg         mem_clear;      // Declarado
reg  [3:0]  mem_wa;
reg  [15:0] mem_wd;
reg  [3:0]  mem_addr_mux;

reg  [2:0]  opcode;
reg  [3:0]  dest;
reg  [3:0]  src1;
reg  [3:0]  src2;
reg  [5:0]  imm;
reg         imms;

// Decodificador combinacional
always @(*) begin
    opcode = data[17:15];
    dest   = 4'd0;
    src1   = 4'd0;
    src2   = 4'd0;
    imm    = data[5:0];
    imms   = data[6];

    case (opcode)
        // Tipo 3: LOAD
        3'b000: begin
            dest = data[14:11];
            imms = data[6];
            imm  = data[5:0];
        end
        // Tipo 1: ADD / SUB
        3'b001, 3'b011: begin
            dest = data[14:11];
            src1 = data[10:7];
            src2 = data[6:3];
        end
        // Tipo 2: ADDI / SUBI / MUL
        3'b010, 3'b100, 3'b101: begin
            dest = data[14:11];
            src1 = data[10:7];
            imms = data[6];
            imm  = data[5:0];
        end
        // Tipo 4: CLEAR / DISPLAY
        3'b110, 3'b111: begin
            dest = data[14:11];
            src1 = data[14:11];
        end
    endcase
end

module_alu ula_inst (
    .clk       (clk),
    .opcode    (opcode),
    .valor1    (reg_val1),
    .valor2    (mem_q),
    .imm       (imm),
    .imms      (imms),
    .resultado (alu_result)
);

memory mem_inst (
    .clk   (clk),
    .we    (mem_we),
    .clear (mem_clear),     // Conectado
    .addr  (mem_addr_mux),
    .data  (mem_wd),
    .q     (mem_q)
);

localparam WAIT_BUTTON = 3'd0,
           FETCH       = 3'd1,
           DECODE      = 3'd2,
           EXECUTE     = 3'd3,
           WRITE_BACK  = 3'd4,
           LCD_UPDATE  = 3'd5;

reg [2:0]  estado_atual = WAIT_BUTTON;
reg [19:0] deb_on_cnt   = 20'd0;
reg        on_off_sync  = 1'b1;
reg        on_off_prev  = 1'b1;

reg [19:0] deb_env_cnt  = 20'd0;
reg        enviar_sync  = 1'b1;
reg        enviar_prev  = 1'b1;
// Sinais de controle do LCD
reg        sistema_on   = 1'b0;
reg        tela_inicial = 1'b1;
reg        lcd_atualizar;
reg [2:0]  lcd_opcode_reg;
reg [3:0]  lcd_dest_reg;
reg [15:0] lcd_valor_reg;
assign 	  lcd_on = sistema_on;

// contador para estabilização inical
reg [19:0] boot_cnt = 20'd0;
wire       pronto   = (boot_cnt == 20'd500_000);

wire on_off_solto = (on_off_prev == 1'b0 && on_off_sync == 1'b1);
wire enviar_solto = (enviar_prev == 1'b0 && enviar_sync == 1'b1);

// Instância do controlador do LCD usando os valores salvos
lcd lcd_inst (
    .clk          (clk),
    .sistema_on   (sistema_on),
    .atualizar    (lcd_atualizar),
    .tela_inicial (tela_inicial),
    .opcode       (lcd_opcode_reg),
    .reg_dest     (lcd_dest_reg),
    .valor_16b    (lcd_valor_reg),
    .lcd_data     (lcd_data),
    .lcd_rs       (lcd_rs),
    .lcd_rw       (lcd_rw),
    .lcd_en       (lcd_en)
);

always @(*) begin
    if (mem_we)
        mem_addr_mux = mem_wa;
    else if (estado_atual == FETCH)
        mem_addr_mux = src1;
    else
        mem_addr_mux = src2;
end

// Único bloco sequencial da CPU
always @(posedge clk) begin
    if (!pronto) begin
        boot_cnt      <= boot_cnt + 20'd1;
        on_off_sync   <= on_off;
        on_off_prev   <= on_off;
        enviar_sync   <= enviar;
        enviar_prev   <= enviar;
        deb_on_cnt    <= 20'd0;
        deb_env_cnt   <= 20'd0;
        sistema_on    <= 1'b0;
        lcd_atualizar <= 1'b0;
        mem_clear     <= 1'b1;
        mem_we        <= 1'b0;
        estado_atual  <= WAIT_BUTTON;
    end else begin
        // [MODIFICADO] Filtro de debounce de 15 ms (750.000 ciclos) para on_off
        if (on_off != on_off_sync) begin
            if (deb_on_cnt >= 20'd750_000) begin
                on_off_sync <= on_off;
                deb_on_cnt  <= 20'd0;
            end else begin
                deb_on_cnt <= deb_on_cnt + 20'd1;
            end
        end else begin
            deb_on_cnt <= 20'd0;
        end

        // [MODIFICADO] Filtro de debounce de 15 ms (750.000 ciclos) para enviar
        if (enviar != enviar_sync) begin
            if (deb_env_cnt >= 20'd750_000) begin
                enviar_sync <= enviar;
                deb_env_cnt <= 20'd0;
            end else begin
                deb_env_cnt <= deb_env_cnt + 20'd1;
            end
        end else begin
            deb_env_cnt <= 20'd0;
        end

        on_off_prev   <= on_off_sync;
        enviar_prev   <= enviar_sync;
        lcd_atualizar <= 1'b0;
        mem_clear     <= 1'b0;
		  
		 if (on_off_solto) begin
        sistema_on   <= ~sistema_on;
        tela_inicial <= 1'b1;
        mem_clear    <= 1'b1; // Zera toda a memória ao ligar/desligar
        mem_we       <= 1'b0;
        estado_atual <= WAIT_BUTTON;
    end else if (!sistema_on) begin
        mem_we       <= 1'b0;
        estado_atual <= WAIT_BUTTON;
    end else begin
        case (estado_atual)
            WAIT_BUTTON: begin
                mem_we <= 1'b0;
                if (enviar_solto) begin
                    estado_atual <= FETCH;
                end
            end

            FETCH: begin
                estado_atual <= DECODE;
            end

            DECODE: begin
                reg_val1     <= mem_q;
                estado_atual <= EXECUTE;
            end

            EXECUTE: begin
                estado_atual <= WRITE_BACK;
            end

            WRITE_BACK: begin
                if (opcode == 3'b110) begin //se CLEAR, limpa tudo
                    mem_clear <= 1'b1;
                end else if (opcode != 3'b111) begin
                    // Grava alu_result em dest (inclui CLEAR zerando o registrador dest específico)
                    mem_wa <= dest;
                    mem_wd <= alu_result;
                    mem_we <= 1'b1;
                end
                estado_atual <= LCD_UPDATE;
            end

            LCD_UPDATE: begin
                mem_we         <= 1'b0;
                tela_inicial   <= 1'b0;
                lcd_opcode_reg <= opcode;
                lcd_dest_reg   <= dest;
                lcd_valor_reg  <= (opcode == 3'b111) ? reg_val1 : alu_result;
                lcd_atualizar  <= 1'b1; // Dispara a escrita no LCD
                estado_atual   <= WAIT_BUTTON;
            end

            default: estado_atual <= WAIT_BUTTON;
        endcase
		end
	 end
end
endmodule
module module_mini_cpu (
    input  wire        clk,
    input  wire        on_off,
    input  wire        enviar,
    input  wire [17:0] data,
    output wire [7:0]  lcd_data,
    output wire        lcd_rs, 
    output wire        lcd_rw,
    output wire        lcd_en
);    
    wire [15:0] alu_result;
    wire [15:0] mem_q;          // Substitui mem_data_out1 e mem_data_out2
    reg  [15:0] reg_val1;       // Adicionado para salvar o 1º operando
    
    reg         mem_we;
    reg  [3:0]  mem_wa;
    reg  [15:0] mem_wd;
    reg  [3:0]  mem_addr_mux;   // Adicionado (estava sem declaração)

	 reg [2:0] opcode;
	 reg [3:0] dest;
	 reg [3:0] src1;
	 reg [3:0] src2;
	 reg [5:0] imm;
	 reg		  imms;
	 
	 always @(*) begin
		opcode = data [17:15];
		dest = 4'd0;
		src1 = 4'd0;
		src2 = 4'd0;
		imm = data[5:0];
		imms = data [6];
		
		case (opcode)
			//tipo 3 LOAD
			3'b000: begin
			dest = data[14:11];
			src1 = data[10:7];
			src2 = data [6:3];
			end
			//tipo 1 ADD\SUB
			3'b001, 3'b011: begin
			dest = data[14:11];
			src1 = data[10:7];
			src2 = data[6:3];
			end
			//tipo 2 ADDI\SUBI\MUL
			3'b010, 3'b100, 3'b101: begin
			dest = data[14:11];
			src1 = data[10 7:];
			imms = data[6];
			imm = data[5:0];
			end
			//tipo 4 CLEAR\DISPLAY
			3'b110, 3'b111: begin
			dest = data[14:11];
			src1 = data[14:11];
			end
			endcase
	 end
	 
    module_alu ula_inst (
        .clk       (clk),
        .opcode    (opcode), 
        .valor1    (reg_val1),      // Ajustado para reg_val1
        .valor2    (mem_q),         // Ajustado para mem_q
        .imm       (imm),
        .imms      (imms),       // Movido de mem_inst para ula_inst
        .resultado (alu_result)     // Use .result se a porta em module_alu se chamar result
    );

    memory mem_inst (
        .clk  (clk),
        .we   (mem_we), 
        .addr (mem_addr_mux),       // Porta única multiplexada
        .data (mem_wd),             // Porta única de escrita
        .q    (mem_q)               // Porta única de leitura
    );
   
    localparam WAIT_BUTTON = 3'd0,
               FETCH       = 3'd1,
               DECODE      = 3'd2,
               EXECUTE     = 3'd3,
               WRITE_BACK  = 3'd4,
               LCD_UPDATE  = 3'd5;
               
    reg [2:0] estado_atual = WAIT_BUTTON;
    reg       enviar_prev;

	 // Sinais de controle do LCD dentro de module_mini_cpu
    reg        sistema_on   = 1'b0;
    reg        tela_inicial = 1'b1;
    reg        lcd_atualizar;
    reg        on_off_prev;

    // Toggle do botão Ligar/Desligar (age ao soltar o botão)
    always @(posedge clk) begin
        on_off_prev <= on_off;
        if (on_off_prev == 1'b1 && on_off == 1'b0) begin
            sistema_on   <= ~sistema_on;
            tela_inicial <= 1'b1; // Sempre volta para "------ [----] / +00000" ao ligar
        end else if (estado_atual == LCD_UPDATE) begin
            tela_inicial <= 1'b0; // Passa a exibir o resultado da instrução
        end
    end

    // Mux do valor enviado ao LCD (DISPLAY mostra o registrador lido; outras mostram a ULA)
    wire [15:0] lcd_valor_exibido = (data[17:15] == 3'b111) ? reg_val1 : alu_result;

    // Instância do controlador do LCD
    lcd_controller lcd_inst (
        .clk          (clk),
        .sistema_on   (sistema_on),
        .atualizar    (lcd_atualizar),
        .tela_inicial (tela_inicial),
        .opcode       (data[17:15]),
        .reg_dest     (data[14:11]),
        .valor_16b    (lcd_valor_exibido),
        .lcd_data     (lcd_data),
        .lcd_rs       (lcd_rs),
        .lcd_rw       (lcd_rw),
        .lcd_en       (lcd_en)
    );
	 
	 
    always @(*) begin
        if (mem_we)
            mem_addr_mux = mem_wa;     // Endereço de escrita (no LCD_UPDATE)
        else if (estado_atual == FETCH)
            mem_addr_mux = src1; // Endereço do 1º operando (valor1)
        else
            mem_addr_mux = src2;  // Endereço do 2º operando (valor2)
    end
     
    always @(posedge clk) begin
        enviar_prev <= enviar;
        
        case (estado_atual)
            WAIT_BUTTON: begin
                mem_we <= 1'b0; 
                if (enviar_prev == 1'b0 && enviar == 1'b1) begin
                    estado_atual <= FETCH;
                end
            end
            
            FETCH: begin
                estado_atual <= DECODE;
            end
            
            DECODE: begin
                reg_val1     <= mem_q; // Salva o 1º operando lido da memória
                estado_atual <= EXECUTE;
            end
            
            EXECUTE: begin
                estado_atual <= WRITE_BACK;
            end
            
            WRITE_BACK: begin
                if (data[17:15] != 3'd6 && data[17:15] != 3'd7) begin
                    mem_wa <= dest; // Corrigido de memory_wa para mem_wa
                    mem_wd <= alu_result;  // Corrigido de memory_wd para mem_wd
                    mem_we <= 1'b1;        // Corrigido de memory_we para mem_we
                end
                estado_atual <= LCD_UPDATE;
            end
            
            LCD_UPDATE: begin
                mem_we       <= 1'b0;
                estado_atual <= WAIT_BUTTON; 
            end

            default: estado_atual <= WAIT_BUTTON;
        endcase
    end
endmodule
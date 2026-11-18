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

    module_alu ula_inst (
        .clk       (clk),
        .opcode    (data[17:15]), 
        .valor1    (reg_val1),      // Ajustado para reg_val1
        .valor2    (mem_q),         // Ajustado para mem_q
        .imm       (data[5:0]),
        .imms      (data[6]),       // Movido de mem_inst para ula_inst
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

    always @(*) begin
        if (mem_we)
            mem_addr_mux = mem_wa;     // Endereço de escrita (no LCD_UPDATE)
        else if (estado_atual == FETCH)
            mem_addr_mux = data[10:7]; // Endereço do 1º operando (valor1)
        else
            mem_addr_mux = data[6:3];  // Endereço do 2º operando (valor2)
    end
     
    always @(posedge clk) begin
        enviar_prev <= enviar;
        
        case (estado_atual)
            WAIT_BUTTON: begin
                mem_we <= 1'b0; 
                if (enviar_prev == 1'b1 && enviar == 1'b0) begin
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
                    mem_wa <= data[14:11]; // Corrigido de memory_wa para mem_wa
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
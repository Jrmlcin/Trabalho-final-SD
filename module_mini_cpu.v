module module_mini_cpu (
    input wire clk,
    input wire on_off,
    input wire enviar,
    input wire [17:0] data,
    output wire [7:0] lcd_data,
    output wire lcd_rs, 
	 output wire lcd_rw,
	 output wire lcd_en
);    
	 wire [15:0] alu_result;
    wire [15:0] mem_data_out1;
    wire [15:0] mem_data_out2;
    
    reg mem_write_enable;
    reg [3:0] mem_write_addr;
    reg [15:0] mem_write_data;


    module_alu ula_inst (
        .opcode(switches[17:15]), 
        .val1(mem_data_out1), 
        .val2(mem_data_out2),
        .imm(switches[5:0]),
        .resultado(alu_result)
    );
	 memory mem_inst (
        .clk(clk),
        .we(mem_write_enable), 
        .addr_write(memory_wa),
        .data_write(mem_wd),
        .addr_read1(data[10:7]), 
        .data_read1(mem_out1)
    );
   
    localparam WAIT_BUTTON = 3'd0,
               FETCH       = 3'd1,
               DECODE      = 3'd2,
               EXECUTE     = 3'd3,
               WRITE_BACK  = 3'd4,
               LCD_UPDATE  = 3'd5;
               
    reg [2:0] estado_atual = WAIT_BUTTON;
    reg enviar_prev;

    always @(posedge clk) begin
        enviar_prev <= enviar;
        
        case (estado_atual)
            WAIT_BUTTON: begin
                mem_write_enable <= 0; 
                if (enviar_prev == 1 && enviar == 0) begin
                    estado_atual <= FETCH;
                end
            end
            
            FETCH: begin
                estado_atual <= DECODE;
            end
            
            DECODE: begin
                estado_atual <= EXECUTE;
            end
            
            EXECUTE: begin
                estado_atual <= WRITE_BACK;
            end
            
            WRITE_BACK: begin
                if (/* instrução não for DISPLAY ou CLEAR */) begin
                    memory_wa <= data[14:11]; 
                    memory_wd <= alu_result;
                    memory_we <= 1; 
                end
                estado_atual <= LCD_UPDATE;
            end
            
            LCD_UPDATE: begin
                mem_write_enable <= 0;
                estado_atual <= WAIT_BUTTON; 
            end
        endcase
    end
endmodule
module alu (
    input wire [2:0] opcode,
    input wire clk,
    input wire [3:0] src1,
    input wire [3:0] src2,
    input wire [5:0] imm,
    input wire imms,
    input wire [3:0] dest,
    
	 output wire[15:0] memory;
);

    reg [15:0] memory1 [0:15];
    reg [15:0] memory2 [0:15];
    
    wire [15:0] valor1;
    wire [15:0] valor2;
    
    assign valor1 = memory1[src1];
    assign valor2 = memory2[src2];
    
    integer i;
	 reg [15:0] resultado;
    
    // Estados
    localparam [2:0]      S_LOAD = 3'd0,
                          S_ADD  = 3'd1,
                          S_ADDI = 3'd2,
                          S_SUB  = 3'd3,
                          S_SUBI = 3'd4,
                          S_MUL  = 3'd5,
                          S_CLR  = 3'd6,
                          S_DPL  = 3'd7;
                           
    
    always @(negedge clk) begin
        case (opcode)
        
            S_LOAD: begin
					 if(imms == 1)
                memmory[dest] <= -imm;
					 else
					 memory[dest] <= imm;
            end
            
            S_ADD: begin
                memory[dest] <= valor1 + valor2;
            end
            
            S_ADDI: begin
                if (imms == 1'b1)begin
						dest <= valor1 - imm;
					 end
					 else
					 dest <= valor1 + imm;
            end
            
            S_SUB: begin
                dest <= valor1;
            end
            
            S_SUBI: begin
                if (imms == 1'b1)begin
						dest <= valor1 -(-imm);
					 end
					 else
					 dest <= valor1 - imm;
            end
            
            S_MUL: begin
					resultado = 16'd0;
                
                for(i = 0; i < 63; i = i +1)begin
                    if(i < imm)
						  resultado = resultado + valor1;
                end
					 
					 if (imms == 1'b1)begin
						dest <= -resultado;
					 end
					 else
					 dest <= resultado;	 
            end

			endcase
    end
	 
endmodule
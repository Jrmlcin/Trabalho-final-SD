module module_alu (
    input wire [2:0] opcode,
    input wire clk,
    input wire [15:0] valor1,
    input wire [15:0] valor2,
    input wire [5:0] imm,
    input wire imms,
    input wire [3:0] dest,
    
	 output reg [15:0] result
);

    wire [15:0] imm_abs   = {10'd0, imm};
	 wire [15:0] imm_sinal = imms ? (-imms_abs) : imm_abs;
	 
	 integer i;
	 reg [15:0] mul;
    
    // Estados
    localparam [2:0]      S_LOAD = 3'd0,
                          S_ADD  = 3'd1,
                          S_ADDI = 3'd2,
                          S_SUB  = 3'd3,
                          S_SUBI = 3'd4,
                          S_MUL  = 3'd5,
                          S_CLR  = 3'd6,
                          S_DPL  = 3'd7;
                           
    
    always @(posedge clk) begin
        case (opcode)
        
            S_LOAD: begin
					 resultado <= imm_sinal;
            end
            
            S_ADD: begin
                resultado <= valor1 + valor2;
            end
            
            S_ADDI: begin
					 resultado <= valor1 + imm_sinal;
            end
            
            S_SUB: begin
                resultado <= valor1;
            end
            
            S_SUBI: begin
                resultado <= valor1 - imm_sinal;
            end
            
            S_MUL: begin
					mul_acc = 16'd0;
                
                for(i = 0; i < 64; i = i +1)begin
                    if(i < imm)
						  mul_acc = mul_acc + valor1;
                end
					 
					 if (imms == 1'b1)begin
						resultado <= -mul_acc;
					 end
					 else
					 resultado <= mul_acc;	 
            end
				
				S_CLR: begin
					resultado <= 16'd0;
				end
				
				default: begin
					resultado <= 16'd0;
				end

			endcase
    end
	 
endmodule
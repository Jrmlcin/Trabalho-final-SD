module minicpu (
	input wire [2:0] opcode,
	input wire clk,
	input wire [3:0] src1,
	input wire [3:0] src2,
	input wire [5:0] imm,
	input wire [1:0] imms,
	
	output wire [3:0] dest
	

);

	reg [15:0] memory1 [0:15];
	reg [15:0] memory2 [0:15];
	
	wire [15:0] valor1;
	wire [15:0] valor2;
	
	assign valor1 = memory1[src1];
	assign valor2 = memory2[src2];
	
	// Estados
	localparam [3:0] S_LOAD = 3'd0,
						  S_ADD  = 3'd1,
						  S_ADDI = 3'd2,
						  S_SUB  = 3'd3,
						  S_SUBI = 3'd4,
						  S_MUL  = 3'd5,
						  S_CLR  = 3'd6,
						  S_DPL	= 3'd7;
						   
	reg [3:0] state;
	
	always(negedge clk) begin
		case (state)
		
			S_LOAD: begin
				assign dest = valor1;
			end
			
			S_ADD: begin
				assign dest = valor1 + valor2;
			end
			
			S_ADDI: begin
				assign dest = valor1 + valor2
			end
	end
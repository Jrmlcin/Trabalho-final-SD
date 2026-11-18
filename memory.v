module memory (
    input  wire [15:0] data,
    input  wire [3:0] addr, //Como são 16 posições, precisamos de 4bits para representar de 0 a 15
    input  wire       we,
    input  wire       clk,
    output wire [15:0] q
);

    // declaracao da memoria RAM
    reg [15:0] ram [15:0];//Guarda palavras de 16bits em um vetor de 16 posições(0-15)

    // registrador para armazenar o endereço de leitura
    reg [3:0] addr_reg;  // 2^4 = 16 posicoes de memoria
  
    //inicializacao da memoria
    initial begin 
      ram[0]  <= 16'h00;
      ram[1]  <= 16'h00;
      ram[2]  <= 16'h00;
      ram[3]  <= 16'h00;
      ram[4]  <= 16'h00;
      ram[5]  <= 16'h00;
      ram[6]  <= 16'h00;
      ram[7]  <= 16'h00; 
      ram[8]  <= 16'h00;
      ram[9]  <= 16'h00;
      ram[10] <= 16'h00;
      ram[11] <= 16'h00;
      ram[12] <= 16'h00;
      ram[13] <= 16'h00;
      ram[14] <= 16'h00;
      ram[15] <= 16'h00;
    end

    always @(posedge clk) begin
        // escrita na memoria
        if (we)
            ram[addr] <= data;

        // registro do endereco de leitura
        addr_reg <= addr;
    end

    // leitura assincrona com base no endereco registrado
    assign q = ram[addr_reg];

endmodule
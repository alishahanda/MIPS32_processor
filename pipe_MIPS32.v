module pipe_MIPS32 (clk1,clk2);
input clk1,clk2;
reg [31:0] PC, IF_ID_IR, IF_ID_NPC;
reg [31:0] ID_EX_A, ID_EX_B, ID_EX_Imm, ID_EX_NPC, ID_EX_IR;
reg [2:0] ID_EX_type, EX_MEM_type, MEM_WB_type;
reg [31:0] EX_MEM_IR, EX_MEM_B, EX_MEM_ALUOUT;
reg  EX_MEM_cond;
reg [31:0] MEM_WB_LMD, MEM_WB_ALUOUT, MEM_WB_IR;
reg [31:0] Reg [0:31];
reg [31:0] Mem [0:1023];
parameter ADD=6'b000000;

parameter SUB=6'b000001,
AND=6'b000010, 
OR=6'b000011,
SLT=6'b000100,
MUL=6'b000101,
HLT=6'b111111,
LW=6'b001000,
SW=6'b001001;
parameter ADDI=6'b001010,
SUBI=6'b001011,
SLTI=6'b001100,
BNEQZ=6'b001101,
BEQZ=6'b001110;
parameter 
RR_ALU=3'b000,
RM_ALU=3'b001,
LOAD=3'b010,
STORE=3'b011,
BRANCH=3'b100,
HALT=3'b101;
reg HALTED;
reg TAKEN_BRANCH;
// IF stage 
always @(posedge clk1)
if (HALTED==0)
begin 
if (( (IF_ID_IR[31:26]==BEQZ) && (EX_MEM_cond ==1) || (IF_ID_IR[31:26]==BNEQZ) && (EX_MEM_cond ==0)))
begin
TAKEN_BRANCH <= 1'b1;
IF_ID_IR <= Mem[EX_MEM_ALUOUT];
IF_ID_NPC <= EX_MEM_ALUOUT+1;
PC<= EX_MEM_ALUOUT+1;
end
else 
begin 
IF_ID_IR <= Mem[PC];
PC <= PC+1;
IF_ID_NPC<= PC+1; 
end 
end
// ID stage 
always @(posedge clk2)

if (HALTED==0)
begin 
if (IF_ID_IR[25:21]== 5'b00000) ID_EX_A<=0;
else ID_EX_A <= Reg[IF_ID_IR[25:21]];
if (IF_ID_IR[20:16]== 5'b00000) ID_EX_B<=0;
else ID_EX_B <= Reg[IF_ID_IR[20:16]];
ID_EX_NPC<=IF_ID_NPC;
ID_EX_IR<= IF_ID_IR;
ID_EX_Imm<={{16{IF_ID_IR[15]}}, {IF_ID_IR[15:0]}}; 

case (IF_ID_IR[31:26])
ADD,SUB,AND,OR,SLT,MUL: ID_EX_type <= RR_ALU;
ADDI,SUBI,SLTI: ID_EX_type <= RM_ALU;
LW: ID_EX_type <= LOAD;
SW: ID_EX_type <= STORE;
BNEQZ,BEQZ: ID_EX_type <= BRANCH;
HLT: ID_EX_type <= HALT;
default: ID_EX_type <= HALT;

endcase
end
// EX stage 
always @(posedge clk1)
if (HALTED==0)
begin
EX_MEM_IR<=ID_EX_IR;
EX_MEM_type<=ID_EX_type;
TAKEN_BRANCH <= 0;
case(ID_EX_type)
RR_ALU: begin 
case (ID_EX_IR[31:26])
ADD: EX_MEM_ALUOUT<= ID_EX_A + ID_EX_B;
SUB: EX_MEM_ALUOUT <=  ID_EX_A - ID_EX_B;
AND: EX_MEM_ALUOUT <=  ID_EX_A & ID_EX_B;
OR: EX_MEM_ALUOUT <=  ID_EX_A | ID_EX_B;
SLT: EX_MEM_ALUOUT <=  ID_EX_A < ID_EX_B;
MUL: EX_MEM_ALUOUT <=  ID_EX_A * ID_EX_B;
default: EX_MEM_ALUOUT <=  32'hxxxxxxxx;
endcase 
end 
RM_ALU: begin 
case (ID_EX_IR[31:26])
ADDI: EX_MEM_ALUOUT <= ID_EX_A + ID_EX_Imm;
SUBI: EX_MEM_ALUOUT <=  ID_EX_A - ID_EX_Imm;
SLTI: EX_MEM_ALUOUT <=  ID_EX_A < ID_EX_Imm;
default: EX_MEM_ALUOUT <= #2 32'hxxxxxxxx;
endcase 
end
LOAD,STORE:begin
EX_MEM_ALUOUT <= ID_EX_A + ID_EX_Imm;
EX_MEM_B<=ID_EX_B;
end
BRANCH: begin
EX_MEM_ALUOUT<= ID_EX_NPC + ID_EX_Imm;
EX_MEM_cond<= (ID_EX_A==0);
TAKEN_BRANCH<=1;
end
endcase 
end
//MEM
always @(posedge clk2)
if (HALTED==0)
begin

MEM_WB_IR<=EX_MEM_IR;
MEM_WB_type<= EX_MEM_type;
case(EX_MEM_type)
STORE: 
if(TAKEN_BRANCH==0)
Mem[EX_MEM_ALUOUT]<=EX_MEM_B;
LOAD: 
MEM_WB_LMD<= 
Mem[EX_MEM_ALUOUT];
RR_ALU,RM_ALU:
MEM_WB_ALUOUT<=EX_MEM_ALUOUT;
endcase
end

always @(posedge clk1) // WB Stage
begin
if (TAKEN_BRANCH == 0) // Disable write if branch taken
case (MEM_WB_type)
RR_ALU: Reg[MEM_WB_IR[15:11]] <= #2 MEM_WB_ALUOUT; // "rd"
RM_ALU: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_ALUOUT; // "rt"
LOAD: Reg[MEM_WB_IR[20:16]] <= #2 MEM_WB_LMD; // "rt"
HALT: HALTED <= #2 1'b1;
endcase
end
endmodule



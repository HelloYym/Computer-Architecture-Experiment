`include "define.vh"


/**
 * MIPS 5-stage pipeline CPU Core, including data path and co-processors.
 * Author: Zhao, Hongyu  <power_zhy@foxmail.com>
 */
module mips_core (
	input wire clk,  // main clock
	input wire rst,  // synchronous reset
	input wire interrupt,  // interrupt source
	// debug
	`ifdef DEBUG
	input wire debug_en,  // debug enable
	input wire debug_step,  // debug step clock
	input wire [6:0] debug_addr,  // debug address
	output wire [31:0] debug_data,  // debug data
	`endif
	// instruction interfaces
	output wire inst_ren,  // instruction read enable signal
	output wire [31:0] inst_addr,  // address of instruction needed
	input wire [31:0] inst_data,  // instruction fetched
	// memory interfaces
	output wire mem_ren,  // memory read enable signal
	output wire mem_wen,  // memory write enable signal
	output wire [31:0] mem_addr,  // address of memory
	output wire [31:0] mem_dout,  // data writing to memory
	input wire [31:0] mem_din  // data read from memory
	);
	
	// control signals
	wire [31:0] inst_data_ctrl;
	
	wire [2:0] pc_src_ctrl;
	wire imm_ext_ctrl;
	wire [1:0] exe_a_src_ctrl, exe_b_src_ctrl;
	wire [1:0] exe_fwd_a_ctrl, exe_fwd_b_ctrl;
	wire [3:0] exe_alu_oper_ctrl;
	wire mem_ren_ctrl;
	wire mem_wen_ctrl;
	wire [1:0] wb_addr_src_ctrl;
	wire wb_data_src_ctrl;
	wire wb_wen_ctrl;
	
	wire sign;
	
	wire [4:0] regw_addr_exe, regw_addr_mem, regw_addr_wb;
	wire wb_wen_exe, wb_wen_mem;
	
	wire mem_ren_exe;
	wire mem_ren_mem;
	wire mem_fwd_m_ctrl;
	
	wire if_rst, if_en, if_valid;
	wire id_rst, id_en, id_valid;
	wire exe_rst, exe_en, exe_valid;
	wire mem_rst, mem_en, mem_valid;
	wire wb_rst, wb_en, wb_valid;
	
	wire rs_rt_equal;
	
	
	
	
	// Co-Processor
	wire jump_en;  // epc_ctrl: force jump enable signal when interrupt authorised or ERET occurred
	wire [31:0] jump_addr;  // epc: target instruction address to jump to
	wire [31:0] ret_addr;	// target instruction address to store when interrupt occurred
	wire [4:0]	addr_cpr;	// CP0 reg address
	wire [31:0] data_r_cpr;	// CP0 read data
	wire [31:0] data_w_cpr; 	// CP0 write reg data
	wire [1:0] cp_oper_ctrl;  // CP0 operation type
	wire ir_en;
	
	wire [31:0] debug_data_cp0;
	
	
	// controller
	controller CONTROLLER (
		.clk(clk),
		.rst(rst),
		`ifdef DEBUG
		.debug_en(debug_en),
		.debug_step(debug_step),
		`endif
		.inst(inst_data_ctrl),

		.regw_addr_exe(regw_addr_exe),
		.wb_wen_exe(wb_wen_exe),

		
		.regw_addr_mem(regw_addr_mem),
		.wb_wen_mem(wb_wen_mem),
		
		//add for forward
		.mem_ren_exe(mem_ren_exe),
		.mem_ren_mem(mem_ren_mem),
		.exe_fwd_a(exe_fwd_a_ctrl),
		.exe_fwd_b(exe_fwd_b_ctrl),
		.mem_fwd_m(mem_fwd_m_ctrl),
		
		//add for signed
		.sign(sign),
		
		.rs_rt_equal(rs_rt_equal),
		
		.pc_src(pc_src_ctrl),
		.imm_ext(imm_ext_ctrl),
		.exe_a_src(exe_a_src_ctrl),
		.exe_b_src(exe_b_src_ctrl),
		
		// Co Processor
		.cp_oper(cp_oper_ctrl), 
		.ir_en(ir_en),
		.jump_en(jump_en),
		
		.exe_alu_oper(exe_alu_oper_ctrl),
		.mem_ren(mem_ren_ctrl),
		.mem_wen(mem_wen_ctrl),
		.wb_addr_src(wb_addr_src_ctrl),
		.wb_data_src(wb_data_src_ctrl),
		.wb_wen(wb_wen_ctrl),
		.unrecognized(),
		.if_rst(if_rst),
		.if_en(if_en),
		.if_valid(if_valid),
		.id_rst(id_rst),
		.id_en(id_en),
		.id_valid(id_valid),
		.exe_rst(exe_rst),
		.exe_en(exe_en),
		.exe_valid(exe_valid),
		.mem_rst(mem_rst),
		.mem_en(mem_en),
		.mem_valid(mem_valid),
		.wb_rst(wb_rst),
		.wb_en(wb_en),
		.wb_valid(wb_valid)
	);
	

	
	
	cp0 CO_PROCESSOR(
		.clk(clk),
	
		/*
		`ifdef DEBUG
		.debug_addr(debug_addr[4:0]),
		.debug_data(debug_data_cp0),
		`endif
		*/
	
		// operations (read in ID stage and write in EXE stage)
		.oper(cp_oper_ctrl),		// CP0 operation type
		.addr_r(addr_cpr),			// read address
		.data_r(data_r_cpr),		// read data
		.addr_w(addr_cpr),			// write address
		.data_w(data_w_cpr),		// write data
		
		
	
		// exceptions (check exceptions in MEM stage)
		.rst(rst),  // synchronous reset
		.ir_en(ir_en),  // interrupt enable
		.ir_in(interrupt),  // external interrupt input
		.ret_addr(ret_addr),  // target instruction address to store when interrupt occurred
		.jump_en(jump_en),  // force jump enable signal when interrupt authorised or ERET occurred
		.jump_addr(jump_addr)  // target instruction address to jump to
		
    );
	 
	 

	
	// data path
	datapath DATAPATH (
		.clk(clk),
		`ifdef DEBUG
		.debug_addr(debug_addr[5:0]),
		.debug_data(debug_data),
		`endif
		.inst_data_id(inst_data_ctrl),
		.regw_addr_exe(regw_addr_exe),
		.wb_wen_exe(wb_wen_exe),
		.regw_addr_mem(regw_addr_mem),
		.wb_wen_mem(wb_wen_mem),
		
		// Co-Processor
		.jump_en(jump_en),
		.jump_addr(jump_addr),
		.ret_addr(ret_addr),
		.addr_cpr(addr_cpr),
		.data_r_cpr(data_r_cpr),
		.data_w_cpr(data_w_cpr),
		
		//add for forward
		.mem_ren_exe(mem_ren_exe),	
		.mem_ren_mem(mem_ren_mem),
		.exe_fwd_a_ctrl(exe_fwd_a_ctrl),
		.exe_fwd_b_ctrl(exe_fwd_b_ctrl),
		
		//add for mem fwd
		.mem_fwd_m_ctrl(mem_fwd_m_ctrl),
		
		//add for sign_ctrl
		.sign_ctrl(sign),
		
		.rs_rt_equal(rs_rt_equal),
		
		.pc_src_ctrl(pc_src_ctrl),
		.imm_ext_ctrl(imm_ext_ctrl),
		.exe_a_src_ctrl(exe_a_src_ctrl),
		.exe_b_src_ctrl(exe_b_src_ctrl),
		
		.exe_alu_oper_ctrl(exe_alu_oper_ctrl),
		.mem_ren_ctrl(mem_ren_ctrl),
		.mem_wen_ctrl(mem_wen_ctrl),
		.wb_addr_src_ctrl(wb_addr_src_ctrl),
		.wb_data_src_ctrl(wb_data_src_ctrl),
		.wb_wen_ctrl(wb_wen_ctrl),
		.if_rst(if_rst),
		.if_en(if_en),
		.if_valid(if_valid),
		.inst_ren(inst_ren),
		.inst_addr(inst_addr),
		.inst_data(inst_data),
		.id_rst(id_rst | jump_en),	// rd rst when CP0 force jump
		.id_en(id_en),
		.id_valid(id_valid),
		.exe_rst(exe_rst),
		.exe_en(exe_en),
		.exe_valid(exe_valid),
		.mem_rst(mem_rst),
		.mem_en(mem_en),
		.mem_valid(mem_valid),
		.mem_ren(mem_ren),
		.mem_wen(mem_wen),
		.mem_addr(mem_addr),
		.mem_dout(mem_dout),
		.mem_din(mem_din),
		.wb_rst(wb_rst),
		.wb_en(wb_en),
		.wb_valid(wb_valid)
	);
	
endmodule

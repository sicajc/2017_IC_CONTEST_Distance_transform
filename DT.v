module DT(input 			clk,
          input			reset,
          output	reg		done,
          output	reg		sti_rd,
          output	reg 	[9:0]	sti_addr,
          input		[15:0]	sti_di,
          output	reg		res_wr,
          output	reg		res_rd,
          output	reg 	[13:0]	res_addr,
          output	reg 	[7:0]	res_do,
          input		[7:0]	res_di);


/*----------PARAMETERS--------*/
parameter IDLE = 'd0;
parameter  RD_ROM= 'd1;
parameter  WB_RAM= 'd2;
parameter  FETCH_ROM_FORWARD= 'd3;
parameter  FETCH_RAM_FORWARD= 'd4;
parameter  FORWARD= 'd5;
parameter  BACKWARD_PREPROCESS= 'd6;
parameter  FETCH_ROM_BACKWARD= 'd7;
parameter  FETCH_RAM_BACKWARD= 'd8;
parameter  BACKWARD= 'd9;
parameter  DONE= 'd10;

//!Registers
reg[9:0] row_and_rom_index_reg;
reg[13:0] col_and_ram_index_reg;
reg[3:0] counter_reg;
reg[3:0] fetch_ram_counter_reg;
reg[7:0] for_back_reg[0:3];
reg[7:0] ref_point_reg;
reg[15:0] rom_to_ram_temp_reg;

reg[4:0] current_state,next_state;

/*--------------------MAIN_CTR--------------------*/
always @(posedge clk or posedge reset)
begin
    current_state <= reset ? IDLE : next_state;
end

always @(*)
begin
    case(current_state)



        default:
        begin

        end
    endcase

end




//ref_point_reg
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin

    end
    else
    begin




    end
end

integer i;
//for_back_reg
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        for(i = 0;i<4;i = i+1)
        begin
            for_back_reg[i] <= 'd0;
        end
    end
    else
    begin

    end
end
//col_and_ram_index_reg
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        col_and_ram_index_reg <= 'd0;
    end
    else
    begin


    end
end
//row and rom index reg
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        row_and_rom_index_reg <= 'd0;
    end
    else
    begin



    end
end
//ref_point_reg
always @(posedge clk or posedge reset)
begin
    if (reset)
    begin
        ref_point_reg <= 'd0;
    end
    else
    begin



    end
end

//rom to ram temp reg
always @(posedge clk or posedge reset)
begin



end


/*----------------------Distance_transform_unit------------------*/

wire[7:0] min1;
four_num_sorter #(8) MIN1(.a(for_back_reg[0]),.b(for_back_reg[1]),.c(for_back_reg[2]),.d(for_back_reg[3]),.min(min1));

wire[7:0] resulted_min;
wire is_backward_window_flag;

assign compared_pixel = is_backward_window_flag ? ref_point_reg : 'd128;
assign resulted_min   = min1 < compared_pixel ? min1 + 'd1 : compared_pixel + 'd1;



endmodule

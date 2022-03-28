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
parameter IDLE                 = 'd0;
parameter  RD_ROM              = 'd1;
parameter  WB_RAM              = 'd2;
parameter  FETCH_ROM_FORWARD   = 'd3;
parameter  FETCH_RAM_FORWARD   = 'd4;
parameter  FORWARD             = 'd5;
parameter  BACKWARD_PREPROCESS = 'd6;
parameter  FETCH_ROM_BACKWARD  = 'd7;
parameter  FETCH_RAM_BACKWARD  = 'd8;
parameter  BACKWARD            = 'd9;
parameter  DONE                = 'd10;

//!Registers
reg[9:0] row_and_rom_index_reg;
reg[13:0] col_and_ram_index_reg;
reg[3:0] counter_reg;
reg[3:0] fetch_ram_counter_reg;
reg[7:0] for_back_reg[0:3];
reg[7:0] ref_point_reg;
reg[15:0] rom_to_ram_temp_reg;
reg[4:0] current_state,next_state;

//state flags
wire state_IDLE                = current_state == IDLE;
wire state_RD_ROM              = current_state == RD_ROM;
wire state_WB_RAM              = current_state == WB_RAM;
wire state_FETCH_ROM_FORWARD   = current_state == FETCH_ROM_FORWARD;
wire state_FETCH_RAM_FORWARD   = current_state == FETCH_RAM_FORWARD;
wire state_FORWARD             = current_state == FORWARD;
wire state_BACKWARD_PREPROCESS = current_state == BACKWARD_PREPROCESS;
wire state_FETCH_ROM_BACKWARD  = current_state == FETCH_ROM_BACKWARD ;
wire state_FETCH_RAM_BACKWARD  = current_state == FETCH_RAM_BACKWARD;
wire state_BACKWARD            = current_state == BACKWARD;
wire state_DONE                = current_state == DONE;


wire rd_rom_done_flag = row_and_rom_index_reg == 'd1023;
wire wb_ram_done_flag = counter_reg == 'd15;
wire forward_data_fetch_done_flag = fetch_ram_counter_reg == 'd3;
wire forward_window_done_flag = row_and_rom_index_reg == 'd0;

wire refetch_rom_flag = counter_reg == 'd15;
wire backward_data_fetch_done_flag = fetch_ram_counter_reg == 'd4;
wire backward_window_done_flag = row_and_rom_index_reg =='d1023;


/*--------------------MAIN_CTR--------------------*/
always @(posedge clk or posedge reset)
begin
    current_state <= reset ? IDLE : next_state;
end

always @(*)
begin
    case(current_state)
        IDLE:
        begin
            next_state = RD_ROM;
        end
        RD_ROM:
        begin
            next_state = WB_RAM;
        end
        WB_RAM:
        begin
            if (rd_rom_done_flag)
            begin
                next_state = RD_ROM;
            end
            else if (wb_ram_done_flag)
            begin
                next_state = FETCH_ROM_FORWARD;
            end
            else
            begin
                next_state = WB_RAM;
            end
        end
        FETCH_ROM_FORWARD:
        begin
            next_state = FETCH_RAM_FORWARD;
        end
        FETCH_RAM_FORWARD:
        begin
            next_state = forward_data_fetch_done_flag ? FORWARD : FETCH_RAM_FORWARD;
        end
        FORWARD:
        begin
            if (forward_window_done_flag)
            begin
                next_state = BACKWARD_PREPROCESS;
            end
            else if (refetch_rom_flag)
            begin
                next_state = FETCH_ROM_FORWARD;
            end
            else
            begin
                next_state = FETCH_RAM_FORWARD;
            end
        end
        BACKWARD_PREPROCESS:
        begin
            next_state = FETCH_ROM_BACKWARD;
        end
        FETCH_ROM_BACKWARD:
        begin
            next_state = FETCH_RAM_BACKWARD;
        end
        FETCH_RAM_BACKWARD:
        begin
            next_state = backward_data_fetch_done_flag ? BACKWARD : FETCH_RAM_BACKWARD;
        end
        BACKWARD:
        begin
            if (backward_window_done_flag)
            begin
                next_state = DONE;
            end
            else if (refetch_rom_flag)
            begin
                next_state = FETCH_ROM_BACKWARD;
            end
            else
            begin
                next_state = FETCH_RAM_BACKWARD;
            end
        end
        DONE:
        begin
            next_state = IDLE;
        end
        default:
        begin
            next_state = IDLE;
        end
    endcase
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
        if (state_FETCH_RAM_BACKWARD)
            ref_point_reg <= res_di;
        else if (state_BACKWARD_PREPROCESS)
            ref_point_reg <= 'd0;
        else
            ref_point_reg <= ref_point_reg;
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
        case(current_state)
            FETCH_RAM_FORWARD,FETCH_RAM_BACKWARD:
            begin
                for_back_reg[counter_reg] <= res_di;
            end
            BACKWARD_PREPROCESS:
            begin
                for(i = 0;i<4;i = i+1)
                begin
                    for_back_reg[i] <= 'd0;
                end
            end

            default:
            begin
                for(i = 0;i<4;i = i+1)
                begin
                    for_back_reg[i] <= for_back_reg[i];
                end
            end
        endcase
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
        case(current_state)
            WB_RAM:
            begin
                col_and_ram_index_reg <= wb_ram_done_flag ? 'd0 : rd_rom_done_flag ? 'd0 : col_and_ram_index_reg + 1;
            end
            FORWARD:
            begin

            end

            default:
            begin
                col_and_ram_index_reg <= col_and_ram_index_reg;
            end
        endcase
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
        case(current_state)
            RD_ROM:
            begin
                row_and_rom_index_reg <= wb_ram_done_flag ? 'd0 : rd_rom_done_flag ? row_and_rom_index_reg + 1 : row_and_rom_index_reg;
            end



        endcase
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


/*---------------------Distance_transform_unit------------------*/

wire[7:0] min1;
four_num_sorter #(8) MIN1(.a(for_back_reg[0]),.b(for_back_reg[1]),.c(for_back_reg[2]),.d(for_back_reg[3]),.min(min1));

wire[7:0] resulted_min;
wire is_backward_window_flag;

assign compared_pixel = is_backward_window_flag ? ref_point_reg : 'd128;
assign resulted_min   = min1 < compared_pixel ? min1 + 'd1 : compared_pixel + 'd1;



endmodule

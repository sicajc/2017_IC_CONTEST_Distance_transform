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




/*----------PARAMETERS----------*/
parameter RAM_SIZE                       = 16384;
parameter ROM_SIZE                       = 1024;
parameter FORWARD_WINDOW_ROM_START_ADDR  = 8;
parameter BACKWARD_WINDOW_ROM_START_ADDR = 1015;



/*----STATES---*/
parameter IDLE                     = 'd0 ;
parameter COPY_FETCH_ROM           = 'd1 ;
parameter COPY_ROM_TO_RAM          = 'd2;
parameter FORWARD_WINDOW_RD_LABEL  = 'd3 ;
parameter FORWARD_WINDOW_RD_PIXEL  = 'd4;
parameter FORWARD_WINDOW_CAL_WB    = 'd5 ;
parameter BACKWARD_WINDOW_RD_LABEL = 'd6 ;
parameter BACKWARD_WINDOW_RD_PIXEL = 'd7;
parameter BACKWARD_WINDOW_CAL_WB   = 'd8;
parameter DONE                     = 'd10;

reg[4:0] current_state,next_state;

wire state_IDLE;
wire state_COPY_FETCH_ROM;
wire state_COPY_ROM_TO_RAM;
wire state_FORWARD_WINDOW_RD_LABEL;
wire state_FORWARD_WINDOW_RD_PIXEL;
wire state_FORWARD_WINDOW_CAL_WB;
wire state_BACKWARD_WINDOW_RD_LABEL;
wire state_BACKWARD_WINDOW_RD_PIXEL;
wire state_BACKWARD_WINDOW_CAL_WB;
wire state_DONE;

assign state_IDLE                     = current_state == IDLE;
assign state_COPY_FETCH_ROM           = current_state == COPY_FETCH_ROM;
assign state_COPY_ROM_TO_RAM          = current_state == COPY_ROM_TO_RAM;
assign state_FORWARD_WINDOW_RD_LABEL  = current_state == FORWARD_WINDOW_RD_LABEL;
assign state_FORWARD_WINDOW_RD_PIXEL  = current_state == FORWARD_WINDOW_RD_PIXEL;
assign state_FORWARD_WINDOW_CAL_WB    = current_state == FORWARD_WINDOW_CAL_WB;
assign state_BACKWARD_WINDOW_RD_LABEL = current_state == BACKWARD_WINDOW_RD_LABEL;
assign state_BACKWARD_WINDOW_RD_PIXEL = current_state == BACKWARD_WINDOW_RD_PIXEL;
assign state_BACKWARD_WINDOW_CAL_WB   = current_state == BACKWARD_WINDOW_CAL_WB ;
assign state_DONE                     = current_state == DONE;

//Registers
reg[15:0] ram_addr_reg;
reg[15:0] ram_addr_reg_in;

reg[15:0] rom_addr_reg;
reg[15:0] rom_addr_reg_in;

reg[5:0] counter_reg;
reg[5:0] counter_reg_in;

reg[15:0] copy_temp_reg;
reg[15:0] copy_temp_reg_in;

reg[15:0] col_pointer_reg,row_pointer_reg;
reg[15:0] col_pointer_reg_in,row_pointer_reg_in;

reg[7:0] pixel_cal_reg[0:4];

//addr requests
reg[15:0] addr_request;

//Flags
wire rom_to_ram_copy_done_flag;
wire sixteen_bit_copy_done_flag;
wire forward_window_done_flag;
wire backward_window_done_flag;
wire is_object_flag;
wire forward_window_rd_pixel_done_flag;
wire backward_window_rd_pixel_done_flag;
wire label_refresh_flag;

assign rom_to_ram_copy_done_flag          = state_COPY_ROM_TO_RAM | state_COPY_FETCH_ROM ? ram_addr_reg == (RAM_SIZE - 1)  : 1'b0;
assign sixteen_bit_copy_done_flag         = state_COPY_ROM_TO_RAM | state_COPY_FETCH_ROM ? counter_reg == 'd15 : 1'b0;
assign forward_window_done_flag           = state_FORWARD_WINDOW_RD_LABEL ? (row_pointer_reg == 'd126) && (col_pointer_reg == 'd126): 1'b0;
assign backward_window_done_flag          = state_BACKWARD_WINDOW_RD_LABEL ? (row_pointer_reg == 'd1) && (col_pointer_reg == 'd1) : 1'b0;
assign is_object_flag                     = state_FORWARD_WINDOW_RD_LABEL | state_BACKWARD_WINDOW_RD_LABEL ? sti_di[col_pointer_reg % 16] : 1'b0;
assign forward_window_rd_pixel_done_flag  = state_FORWARD_WINDOW_RD_PIXEL ? counter_reg == 'd4 : 1'b0;
assign backward_window_rd_pixel_done_flag = state_BACKWARD_WINDOW_RD_PIXEL ? counter_reg == 'd5 : 1'b0;
assign label_refresh_flag                 = state_FORWARD_WINDOW_RD_LABEL | state_BACKWARD_WINDOW_RD_LABEL ? counter_reg == 'd15 : 'b0;

/*--------------MAIN_CTR------------------*/
always @(posedge clk or posedge reset)
begin
    current_state <= !reset ? IDLE : next_state;
end

always @(*)
begin
    case(current_state)
        IDLE :
        begin
            next_state = COPY_FETCH_ROM;
        end
        COPY_FETCH_ROM :
        begin
            next_state = COPY_ROM_TO_RAM;
        end
        COPY_ROM_TO_RAM:
        begin
            next_state = rom_to_ram_copy_done_flag ? FORWARD_WINDOW_RD_LABEL : sixteen_bit_copy_done_flag ? COPY_FETCH_ROM : COPY_ROM_TO_RAM;
        end
        FORWARD_WINDOW_RD_LABEL :
        begin
            next_state = forward_window_done_flag ? BACKWARD_WINDOW_RD_LABEL : is_object_flag ? FORWARD_WINDOW_RD_PIXEL : FORWARD_WINDOW_RD_LABEL;
        end
        FORWARD_WINDOW_RD_PIXEL:
        begin
            next_state = forward_window_rd_pixel_done_flag ? FORWARD_WINDOW_CAL_WB : FORWARD_WINDOW_RD_PIXEL;
        end
        FORWARD_WINDOW_CAL_WB :
        begin
            next_state = FORWARD_WINDOW_RD_LABEL;
        end
        BACKWARD_WINDOW_RD_LABEL :
        begin
            next_state = backward_window_done_flag ? DONE : is_object_flag ? BACKWARD_WINDOW_RD_PIXEL : BACKWARD_WINDOW_RD_LABEL;
        end
        BACKWARD_WINDOW_RD_PIXEL:
        begin
            next_state = backward_window_rd_pixel_done_flag ?  BACKWARD_WINDOW_CAL_WB : BACKWARD_WINDOW_RD_PIXEL ;
        end
        BACKWARD_WINDOW_CAL_WB:
        begin
            next_state = BACKWARD_WINDOW_RD_LABEL;
        end
        DONE :
        begin
            next_state = IDLE;
        end

        default:
        begin
            next_state = IDLE;
        end
    endcase
end


// ram_addr_reg
always @(posedge clk or posedge reset)
begin
    ram_addr_reg <= !reset ? 'd0 : ram_addr_reg_in;
end
// ram_addr_reg_in
always @(*)
begin
    case(current_state)
        IDLE:
        begin
            ram_addr_reg_in = 'd0;
        end
        COPY_ROM_TO_RAM:
        begin
            ram_addr_reg_in = rom_to_ram_copy_done_flag ? 'd0 : sixteen_bit_copy_done_flag ? ram_addr_reg + 'd1 : ram_addr_reg + 'd1;
        end
        default:
        begin
            ram_addr_reg_in = ram_addr_reg;
        end
    endcase
end

// rom_addr_reg
always @(posedge clk or posedge reset) begin
    rom_addr_reg <= !reset ? 'd0 : rom_addr_reg_in;
end
// rom_addr_reg_in
always @(*)
begin
    case(current_state)
        IDLE:
        begin
            rom_addr_reg_in = 'd0;
        end
        COPY_ROM_TO_RAM:
        begin
            rom_addr_reg_in = rom_to_ram_copy_done_flag ?  FORWARD_WINDOW_ROM_START_ADDR : sixteen_bit_copy_done_flag ? rom_addr_reg + 'd1 : rom_addr_reg;
        end
        FORWARD_WINDOW_RD_LABEL:
        begin
            rom_addr_reg_in = forward_window_done_flag ? BACKWARD_WINDOW_ROM_START_ADDR : label_refresh_flag ? rom_addr_reg + 1 : rom_addr_reg;
        end
        BACKWARD_WINDOW_RD_LABEL:
        begin
            rom_addr_reg_in = backward_window_done_flag ? 'd0 : label_refresh_flag ? rom_addr_reg - 1 : rom_addr_reg ;
        end
        default:
        begin
            rom_addr_reg_in = ram_addr_reg;
        end
    endcase
end


// counter_reg
always @(posedge clk or posedge reset)
begin
    counter_reg <= !reset ? 'd0 : counter_reg_in;
end
// counter_reg_in
always @(*)
begin
    case(current_state)
        IDLE:
        begin
            counter_reg_in = 'd0;
        end
        COPY_ROM_TO_RAM:
        begin
            counter_reg_in = rom_to_ram_copy_done_flag ? 'd0 : sixteen_bit_copy_done_flag ? 'd0 : counter_reg + 'd1;
        end
        FORWARD_WINDOW_RD_PIXEL:
        begin
            counter_reg_in = forward_window_rd_pixel_done_flag ? 'd0 : counter_reg + 'd1;
        end
        BACKWARD_WINDOW_RD_PIXEL:
        begin
            counter_reg_in = backward_window_rd_pixel_done_flag ? 'd0 : counter_reg + 'd1;
        end
        default:
        begin
            counter_reg_in = counter_reg;
        end

    endcase
end

// copy_temp_reg
always @(posedge clk or posedge reset)
begin
    copy_temp_reg <= !reset ? 'd0 : copy_temp_reg_in;
end
// copy_temp_reg_in
always @(*)
begin

end

// col_pointer_reg,
always @(posedge clk or posedge reset)
begin
    col_pointer_reg <= !reset ? 'd0 : col_pointer_reg_in;
end
// col_pointer_reg_in

// row_pointer_reg
always @(posedge clk or posedge reset)
begin
    row_pointer_reg <= !reset ? 'd0 : row_pointer_reg_in;
end
// row_pointer_reg_in

//pixel_cal_reg
integer index;
always @(posedge clk or posedge reset)
begin
    if (!reset)
    begin
        for(index = 0;index<5;index = index+1)
        begin
            pixel_cal_reg[index] <= 'd255;
        end
    end
    else
    begin
        case(current_state)
            FORWARD_WINDOW_RD_PIXEL:
            begin
                case(counter_reg)
                    0:  pixel_cal_reg[0] <= res_di;
                    1:  pixel_cal_reg[1] <= res_di;
                    2:  pixel_cal_reg[2] <= res_di;
                    3:  pixel_cal_reg[3] <= res_di;
                    default:
                    begin
                        pixel_cal_reg[counter_reg] <= pixel_cal_reg[counter_reg];
                    end
                endcase
            end
            BACKWARD_WINDOW_RD_PIXEL:
            begin
                case(counter_reg)
                    0:  pixel_cal_reg[0] <= res_di;
                    1:  pixel_cal_reg[1] <= res_di;
                    2:  pixel_cal_reg[2] <= res_di;
                    3:  pixel_cal_reg[3] <= res_di;
                    4:  pixel_cal_reg[4] <= res_di;
                    default:
                    begin
                        pixel_cal_reg[counter_reg] <= pixel_cal_reg[counter_reg];
                    end
                endcase
            end
            default:
            begin
                for(index = 0;index<5;index = index+1)
                begin
                    pixel_cal_reg[index] <= pixel_cal_reg[index];
                end
            end
        endcase
    end

end

//ROM addr converter



//RAM addr converter



//DT CAL UNIT
wire[7:0] min1,min2;
wire[7:0] min3,ref_val;
wire[7:0] dt_cal_result;
wire[7:0] fw_cal_result;
wire[7:0] bw_cal_result;

assign min1    = pixel_cal_reg[0] > pixel_cal_reg[1] ? pixel_cal_reg[1] : pixel_cal_reg[0];
assign min2    = pixel_cal_reg[2] > pixel_cal_reg[3] ? pixel_cal_reg[3] : pixel_cal_reg[2];
assign ref_val = pixel_cal_reg[4];
assign min3    = min1 > min2 ? min2 : min1;

assign dt_cal_result = min3 > ref_val ? ref_val : min3;

assign fw_cal_result = state_FORWARD_WINDOW_CAL_WB & is_object_flag ? dt_cal_result + 1 : 'bx;
assign bw_cal_result = state_BACKWARD_WINDOW_CAL_WB & is_object_flag ? dt_cal_result + 1 : 'bx;



endmodule

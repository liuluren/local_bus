module local_bus_master (
                  Clk                     ,
                  Reset                   ,
                                          
                //inner  interface        
                  tx_data                 ,
                  tx_data_valid           ,
                  tx_chl                  ,
                  rx_data                 ,
                  rx_data_valid           ,
                  rx_chl                  ,
                  tx_busy                 ,               
                                          
                //outside interface       
                  lbus_tx_ready           ,
                  lbus_en                 ,
                  lbus_op                 ,
                  lbus_dat                
                  );                      
                                          
input             Clk                     ;
input             Reset                   ;
                                          
output  [7:0]     tx_data                 ;
output            tx_data_valid           ;
output  [1:0]     tx_chl                  ;
input   [7:0]     rx_data                 ;
input             rx_data_valid           ;
input   [1:0]     rx_chl                  ;
input             tx_busy                 ;
                                          
input             lbus_tx_ready           ;
output            lbus_en                 ;
output  [1:0]     lbus_op                 ;
inout   [9:0]     lbus_dat                ;//port 2 + dat 8
//================================================================================================\\
localparam        ST_IDLE       = 2'd0    ;
localparam        ST_WR_DAT     = 2'd1    ;
localparam        ST_RD_DAT     = 2'd2    ;
reg  [1:0]        State         = ST_IDLE ;
                  
reg               lbus_en       = 'b0     ;
reg  [1:0]        lbus_op       = 'b0     ;
reg  [9:0]        lbus_dat_wr   = 10'hff  ;//default chl=0
reg  [7:0]        tx_data       = 'b0     ;
reg  [1:0]        tx_chl        = 'b0     ;
reg               tx_data_valid = 'b0     ;
reg  [9:0]        rxbuf[2:0]              ;
reg  [2:0]        rx_begin      = 'b0     ;
reg  [2:0]        rx_end        = 'b0     ;

assign lbus_dat = (lbus_op==2'b01)?lbus_dat_wr : 10'hz ;

always @(posedge Clk)
begin
    if (rx_data_valid == 1'b1)
        begin
            $display("PDC RX: [%x]\n", rx_data);
            rxbuf[rx_end] <= {rx_chl,rx_data}  ;
            rx_end        <= rx_end + 1'b1     ;
        end  
end

always@(posedge Clk)
begin
    case(State)
        ST_IDLE :
            begin
                if(lbus_tx_ready==1'b0 && rx_data_valid==1'b1)
                    State     <= ST_WR_DAT   ;
                else if(lbus_tx_ready==1'b1 && tx_busy==1'b0)         
                    State     <= ST_RD_DAT    ;
                else                        
                    State     <= State      ;
                                            
                lbus_en       <= 1'b0       ; 
                lbus_op       <= 'b0        ;
                tx_data_valid <= 'b0        ;               
            end

        ST_WR_DAT : // write one byte
            begin
                if(rx_begin != rx_end)
                    begin
                        State        <= ST_IDLE         ;
                        lbus_en      <= 1'b1            ;
                        lbus_op      <= 2'b01           ;
                        lbus_dat_wr  <= rxbuf[rx_begin] ;
                        rx_begin     <= rx_begin + 1'b1 ;
                    end
                else
                    begin
                        lbus_en      <= 1'b0            ;
                        lbus_op      <= lbus_op         ;
                        lbus_dat_wr  <= 10'hff          ;
                        rx_begin     <= rx_begin        ;
                    end
            end
            
        ST_RD_DAT : // read one byte
            begin
                State         <= ST_IDLE       ;
                lbus_en       <= 1'b1          ;
                lbus_op       <= 2'b10         ;
                tx_data       <= lbus_dat[7:0] ;
                tx_chl        <= lbus_dat[9:8] ;
                tx_data_valid <= 1'b1          ;
            end
        
        default :
            begin
                State <= ST_IDLE ;
            end
    endcase
end

endmodule

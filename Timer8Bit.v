module testbench;
    reg PCLK, PRESETn, PSEL, PENABLE, PWRITE;
    reg [1:0] PADDR;
    reg [7:0] PWDATA;
    wire [7:0] PRDATA;
    wire PREADY, PSLVERR;
    wire [7:0] TDR, TCR, TSR;
    reg [3:0] clk;
    always @(posedge PCLK ) begin
           
            clk <= clk + 1 ;
             
    end  
    // Instantiate the module:  unit test
    Timer_8bit UT (
        .clk (clk),
        .PCLK(PCLK),
        .PRESETn(PRESETn),
        .PSEL(PSEL),
        .PENABLE(PENABLE),
        .PWRITE(PWRITE),
        .PADD(PADDR),
        .PWDATA(PWDATA),
        .PRDATA(PRDATA),
        .PREADY(PREADY),
        .PSLVERR(PSLVERR)

    );

    // Clock generation
    always #1 PCLK = ~PCLK;
    

    initial begin
        // Initialize signals
        clk = 0;
        PCLK = 0;
        PRESETn = 0;
        PSEL = 0;
        PENABLE = 0;
        PWRITE = 0;
        PADDR = 8'b11;
        PWDATA = 8'b0;

        // Reset the module
        #10 PRESETn = 1;

        // Write to TDR
        #1 PSEL = 1; #1 PENABLE = 1; #1 PWRITE = 1; PADDR = 2'b00; PWDATA = 8'hF8;
        #1 PENABLE = 0; #1 PSEL = 0; #1 PADDR = 2'b00;
       
        // Write to TCR
        #1 PSEL = 1; #1 PENABLE = 1; #1 PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h80; 
        #1 PENABLE = 0;#1 PSEL = 0;#1 PADDR = 2'b00;
        #16 // 16T can write
        
        // load = 0
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h00; 
        #2 PENABLE = 0; PSEL = 0; 
               
        // Write to TCR , enable =1
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h10;//0001_0000
        #2 PENABLE = 0; PSEL = 0;
        #256
        
        //clear overflow
        #1 PSEL = 1; #1 PENABLE = 1; #1 PWRITE = 1; PADDR = 2'b10; PWDATA = 8'h01;
        #1 PENABLE = 0; #1 PSEL = 0; #1 PADDR = 2'b00;
        
        // count down
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h30;//0011_0000
        #10 PENABLE = 0; PSEL = 0;
       
        #1000
        
        //clear und_flow
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b10; PWDATA = 8'h01;
        #2 PENABLE = 0; PSEL = 0;
        // select clock T4,T8,T16
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h11;
        #10 PENABLE = 0; PSEL = 0;       
        #32
        
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h12;
        #10 PENABLE = 0; PSEL = 0;       
        #32
        
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'h13;
        #10 PENABLE = 0; PSEL = 0;       
        #64
        
        
        
        // Prdata: 4 address
        
        #10 PSEL = 1; PENABLE = 1; PWRITE = 0; PADDR = 2'b00; PWDATA = 8'h00;
        #5 PSEL = 0; #5 PENABLE = 0;    
                
        #10 PSEL = 1; PENABLE = 1; PWRITE = 0; PADDR = 2'b01; PWDATA = 8'h00;
        #5 PSEL = 0; #5 PENABLE = 0;    
        
                
        #10 PSEL = 1; PENABLE = 1; PWRITE = 0; PADDR = 2'b10; PWDATA = 8'h00;
        #5 PSEL = 0;
        #5 PENABLE = 0;  
        
                
        #10 PSEL = 1; PENABLE = 1; PWRITE = 0; PADDR = 2'b11; PWDATA = 8'h00;
        #5 PENABLE = 0; 
        #5 PSEL = 0;    
        
        // Coverage only
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b00; PWDATA = 8'hFF;
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b01; PWDATA = 8'hFF;
        //PWRITE 1 -> 0
        #10 PSEL = 1; PENABLE = 1; PWRITE = 1; PADDR = 2'b00; PWDATA = 8'h00;

        

        // Finish simulation
        #20 PRESETn = 0;
        #10
        $finish;
    end
endmodule


module Timer_8bit(
  input wire [3:0] clk,
  input wire PCLK,
  input wire PRESETn,
  input wire PSEL,
  input wire PWRITE,
  input wire PENABLE,
  input wire [1:0] PADD,
  input wire [7:0] PWDATA,
  output wire [7:0] PRDATA,
  output wire PREADY,
  output wire PSLVERR
  );
  //clk  :  2T 4T 8T 16T
  // PCLK : 1T
  reg[7:0] reg_TDR;
  reg[7:0] reg_TCR;
  reg[1:0] reg_TSR;
  reg[7:0] reg_TCNT;
  reg[7:0] reg_TCNT2;
  wire enable_tdr;
  wire enable_tcr;
  wire enable_tsr;
  wire select_clk;
  wire hw_ovf;
  wire hw_udf;
  wire [7:0] up_dw_8bit;
  wire [7:0] tcnt_normal;
  wire load,enable, up_dw; 
  wire [7:0] nxt_tcnt;
  
  assign PREADY = 1'b1;
  assign PSLVERR = 1'b0;
  // decoder
  assign enable_tcr = PENABLE & PSEL & (PADD == 2'b01);
  assign enable_tdr = PENABLE & PSEL & PADD == 2'b00;
  assign enable_tsr = PENABLE & PSEL & PADD == 2'b10;
//  assign hw_ovf = (reg_TCNT == 0) & (reg_TCNT2 == 8'hFF);
//  assign hw_udf = (reg_TCNT == 8'hFF) & (reg_TCNT2 == 0);
//Status bit OVF is set to 1 at the final system clock before counter 
//changes from 8?hFF to 8?h00 
  assign hw_ovf = (reg_TCNT == 8'hFF) & (nxt_tcnt == 8'h0);
  assign hw_udf = (reg_TCNT == 8'h0) & (nxt_tcnt == 8'hFF);
  //PRDATA
  assign PRDATA = (PWRITE == 0 & enable_tdr) ? reg_TDR :
                  (PWRITE == 0 & enable_tcr) ? reg_TCR :
                  (PWRITE == 0 & enable_tsr) ? reg_TSR :
                  8'b0; 
                  
  // TDR
  always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TDR <= 8'b0;    // Reset TDR v? 0     
        end else if (enable_tdr & PWRITE) begin
                // Ghi d? li?u v�o TDR
            reg_TDR <= PWDATA;
        end       
    end
    //TSR
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TSR[0] <= 1'b0;     
        end else if (enable_tsr & PWRITE) begin
          //  reg_TSR[0] <= PWDATA[0];
            reg_TSR[0] <= 1'b0;
        end else if (hw_ovf)   begin
            reg_TSR[0] <= 1'b1;
          
      end    
    end
    
    // TSR
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TSR[1] <= 1'b0;     
        end else if (enable_tsr & PWRITE) begin
          //  reg_TSR[0] <= PWDATA[0];
            reg_TSR[1] <= 1'b0;
        end else if (hw_udf)   begin
            reg_TSR[1] <= 1'b1;
          
      end    
    end
    
    //TCR
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TCR <= 8'b0;       
        end else if (enable_tcr & PWRITE) begin
                
            reg_TCR <= PWDATA;
        end        
    end
    
assign select_clk = (reg_TCR[1:0] == 2'b00) ? clk[0] :
                    (reg_TCR[1:0] == 2'b01) ? clk[1] :
                    (reg_TCR[1:0] == 2'b10) ? clk[2] :
                                              clk[3];
                                          
         //
    always @(posedge select_clk or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TCNT <= 8'b0;       
        end else begin             
            reg_TCNT <= nxt_tcnt ;
        end        
    end  
    // TCNT2
    
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            reg_TCNT2 <= 8'b0;       
        end else begin             
            reg_TCNT2 <= reg_TCNT ;
        end        
    end                                           
assign load = reg_TCR[7];
assign enable = reg_TCR[4];
assign up_dw = reg_TCR[5];

assign nxt_tcnt =    (load == 1 ) ? reg_TDR[7:0] : tcnt_normal[7:0] ;
assign tcnt_normal = (enable == 1) ? up_dw_8bit : reg_TCNT;
assign up_dw_8bit =  (up_dw == 1) ? reg_TCNT - 1 : reg_TCNT + 1; 
    
endmodule
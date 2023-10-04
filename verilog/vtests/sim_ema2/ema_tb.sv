`timescale 1ns/1ps

module ema_tb();

logic           ACLK;
logic           ARESETN;

logic [31:0]    S_AXIS_TDATA;
logic [3:0]     S_AXIS_TKEEP;
logic           S_AXIS_TLAST;
logic           S_AXIS_TVALID;
wire            S_AXIS_TREADY;

wire [31:0]     M_AXIS_TDATA;
wire [3:0]      M_AXIS_TKEEP;
wire            M_AXIS_TLAST;
wire            M_AXIS_TVALID;
logic           M_AXIS_TREADY;

axis_ema_sv ema0(
    .ACLK(ACLK),
    .ARESETN(ARESETN),

    .S_AXIS_TDATA(S_AXIS_TDATA),
    .S_AXIS_TKEEP(S_AXIS_TKEEP),
    .S_AXIS_TLAST(S_AXIS_TLAST),
    .S_AXIS_TVALID(S_AXIS_TVALID),
    .S_AXIS_TREADY(S_AXIS_TREADY),

    .M_AXIS_TDATA(M_AXIS_TDATA),
    .M_AXIS_TKEEP(M_AXIS_TKEEP),
    .M_AXIS_TLAST(M_AXIS_TLAST),
    .M_AXIS_TVALID(M_AXIS_TVALID),
    .M_AXIS_TREADY(M_AXIS_TREADY)
    );

always #10 ACLK=~ACLK;

   integer   i;
   reg [31:0] test_write_data;
   reg [31:0] last_read_data;
   logic [31:0] recv;    
   logic        last;


task init_signals();
    ACLK='h0;
    ARESETN='h0;

    S_AXIS_TDATA='h0;
    S_AXIS_TKEEP='h0;
    S_AXIS_TLAST='h0;
    S_AXIS_TVALID='h0;

    M_AXIS_TREADY='h0;
    
   last_read_data = 32'h3E8;
   i = 0;
   test_write_data = 0;
endtask

task send_word(
    input logic [31:0] data,
    input logic last
    );
    
    S_AXIS_TDATA = data;
    S_AXIS_TKEEP = 'hf;
    S_AXIS_TVALID='h1;
    S_AXIS_TLAST = last;
    #1;
    while( S_AXIS_TREADY == 'h0)  begin
        @(negedge ACLK);
        #1;
    end
    
    @(negedge ACLK);
    S_AXIS_TVALID='h0;
    S_AXIS_TLAST='h0;
endtask

task recv_word(
    output logic [31:0] data,
    output logic        last
    );
    
    M_AXIS_TREADY = 'h1;
    #1;
    while (M_AXIS_TVALID == 'h0) begin
        @(negedge ACLK);
        #1;
    end
    
    //@(negedge ACLK);
    data = M_AXIS_TDATA;
    last = M_AXIS_TLAST;
    @(negedge ACLK);
    M_AXIS_TREADY = 'h0;
    
endtask    

task send_and_recv(
    input logic [31:0] send_data,
    input logic        send_last,
    output logic [31:0] recv_data,
    output logic        recv_last
    );
    logic last; //unused for now
    fork
        send_word(send_data, send_last);
        recv_word(recv_data, recv_last);
    join
endtask

initial begin
    init_signals();
    for (int i = 0;i < 16;i++) 
        @(negedge ACLK);
    ARESETN=1;
    
    @(negedge ACLK);
    
    //send_and_recv( 32'h0001000, 0, recv);
    //$display("recv: %h", recv);
    // send_and_recv( 32'h0002000, 1, recv);
    // $display("recv: %h", recv);
    //test sequence here!
    for ( i = 100; i < 32'h640; i=i+100) begin
        test_write_data = i;
        $display("Writing Data: %h", test_write_data);
        send_and_recv(test_write_data, (i == 32'h640-100), recv, last);
        $display( "Read Data: %h Last:%h", recv, last  );

        assert( recv == ((test_write_data >> 2) + (last_read_data >> 2) + (last_read_data >> 1)))
            else $fatal(1, "Bad Test Response: %h != %h", recv,
            ((test_write_data >> 2) + (last_read_data >> 2) + (last_read_data >> 1)) );
        assert (last == (i == 32'h640-100)) else $fatal(1, "Bad Last signal %h != %h", last, (i == 32'h640-100));

        last_read_data = recv;
    end
    
    @(negedge ACLK);
    $display("Testing for correct S_AXIS_TVALID");
    
    for ( i = 100; i < 32'h640; i=i+100) begin
        S_AXIS_TDATA = 'h0; //i[31:0];
        S_AXIS_TKEEP = 'hf;
        S_AXIS_TVALID= 'h0;
        M_AXIS_TREADY = 'h1;
        @(negedge ACLK);
    end
    
    $display("Testing for correct M_AXIS_TREADY");
    for ( i = 100; i < 32'h640; i=i+100) begin
        S_AXIS_TDATA = 'h0; //i[31:0];
        S_AXIS_TKEEP = 'hf;
        S_AXIS_TVALID= 'h1;
        M_AXIS_TREADY = 'h0;
        @(negedge ACLK);
    end
   
    $display("Testing for correct resume");
    test_write_data = 32'hffff;
    $display("Writing Data: %h", test_write_data);
    send_and_recv(test_write_data, 0, recv, last);
    $display( "Read Data: %h", recv );

    assert( recv == ((test_write_data >> 2) + (last_read_data >> 2) + (last_read_data >> 1)))
            else $fatal(1, "Bad Test Response: %h != %h", recv,
            ((test_write_data >> 2) + (last_read_data >> 2) + (last_read_data >> 1)) );
    assert( last == 0) else $fatal(1, "Bad Last: %h != %h", last, 0);
    last_read_data = recv;
    
   
    $display("Testing delayed read");
    M_AXIS_TREADY = 'h0;
    fork
        begin
            test_write_data = 32'hbaad;
            $display("Writing Data: %h", test_write_data);
            send_word(test_write_data, 0);
            test_write_data = 32'hbeef;
            $display("Writing Data: %h", test_write_data);
            send_word(test_write_data, 1);
        end
        begin

            $display("stalling read");
            for (int i = 0; i < 100; ++i) @(negedge ACLK);
            recv_word(recv, last);
            $display( "Read Data: %h", recv );
            recv_word(recv, last);
            $display( "Read Data: %h", recv );
        end
    join

    $display("@@@Passed");
    $finish;
end

endmodule
